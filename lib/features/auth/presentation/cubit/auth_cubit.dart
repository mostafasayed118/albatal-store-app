import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/services/logger.dart';
import '../../../addresses/data/local_address_repository.dart';
import '../../../../core/entities/profile.dart';
import '../../../../core/error/result.dart';
import '../../../storefront/data/storefront_persistence.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/profile_repository.dart';

enum AuthStatus {
  initial,
  checkingSession,
  unauthenticated,
  authenticating,
  authenticated,
  passwordRecovery,
  failure,
}

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.errorMessage,
  });

  final AuthStatus status;
  final Profile? profile;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.unauthenticated;
  bool get isLoading =>
      status == AuthStatus.initial ||
      status == AuthStatus.checkingSession ||
      status == AuthStatus.authenticating;

  AuthState copyWith({
    AuthStatus? status,
    Profile? profile,
    String? errorMessage,
    bool clearProfile = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        profile: clearProfile ? null : (profile ?? this.profile),
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, profile, errorMessage];
}

// ─── Cubit ─────────────────────────────────────────────────

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
    LocalAddressRepository? localAddressRepository,
    LocalStorefrontPersistence? storefrontPersistence,
  })  : _authRepository = authRepository,
        _profileRepository = profileRepository,
        _localAddressRepository = localAddressRepository,
        _storefrontPersistence = storefrontPersistence,
        super(const AuthState()) {
    _listenToAuthChanges();
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  /// Device-local stores wiped on sign-out / account deletion so no
  /// address or order PII survives on the device (audit S9). Optional so
  /// existing call sites stay unchanged; the wipe is a no-op when absent.
  final LocalAddressRepository? _localAddressRepository;
  final LocalStorefrontPersistence? _storefrontPersistence;
  StreamSubscription<Authenticated?>? _authSubscription;

  /// Check for an existing session on app launch.
  Future<void> checkSession() async {
    emit(state.copyWith(status: AuthStatus.checkingSession));
    final result = await _authRepository.checkSession();
    switch (result) {
      case Success(:final value):
        if (value != null) {
          await _loadProfile(value.userId);
        } else {
          emit(state.copyWith(status: AuthStatus.unauthenticated));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
        ));
    }
  }

  /// Sign up with email and password.
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    await _applyAuthResult(result);
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.signIn(
      email: email,
      password: password,
    );
    await _applyAuthResult(result);
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.resetPassword(email);
    switch (result) {
      case Success():
        emit(state.copyWith(status: AuthStatus.passwordRecovery));
      case Failure(:final error):
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
        ));
    }
  }

  /// Update password (called from reset-password screen).
  Future<void> updatePassword(String newPassword) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.updatePassword(newPassword);
    switch (result) {
      case Success():
        emit(state.copyWith(status: AuthStatus.authenticated));
      case Failure(:final error):
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
        ));
    }
  }

  /// Update profile fields.
  Future<void> updateProfile({String? fullName, String? phone}) async {
    if (state.profile == null) return;
    final updated = state.profile!.copyWith(
      fullName: fullName,
      phone: phone,
    );
    final result = await _profileRepository.upsertProfile(updated);
    switch (result) {
      case Success():
        emit(state.copyWith(profile: updated));
      case Failure(:final error):
        Log.w('Profile save failed: ${error.message}',
            category: LogCategory.auth);
      // Don't change the in-memory profile — the user's edit is preserved
      // locally even if the server write failed. A future read will
      // reconcile. Surfacing this as a hard error would lose the user's
      // input on a transient network blip.
    }
  }

  /// Sign out and clear all account state.
  Future<void> signOut() async {
    await _authRepository.signOut();
    await _clearLocalSnapshots();
    emit(state.copyWith(
      status: AuthStatus.unauthenticated,
      clearProfile: true,
    ));
  }

  /// Permanently delete the account (UX-043) and clear local auth state.
  ///
  /// [email] must match the account email — the server refuses mismatches.
  /// Returns the outcome so callers can surface the error locally without
  /// collapsing the whole auth state into [AuthStatus.failure] (that status
  /// is reserved for the sign-in flow).
  Future<Result<void>> deleteAccount({required String email}) async {
    final result = await _authRepository.deleteAccount(email: email);
    switch (result) {
      case Success():
        // The server-side user is gone — clear the local session too.
        await _authRepository.signOut();
        await _clearLocalSnapshots();
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearProfile: true,
        ));
        return const Success(null);
      case Failure(:final error):
        Log.w('Account deletion failed: ${error.message}',
            category: LogCategory.auth);
        return Failure(error);
    }
  }

  /// Clear any error message.
  void clearError() {
    if (state.status == AuthStatus.failure) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  // ─── Private helpers ───────────────────────────────────

  /// Removes on-device address and order snapshots so a signed-out or
  /// deleted device holds no personal data (audit S9). Calls the same
  /// local stores the app reads from — never raw prefs keys. Cart and
  /// wishlist are deliberately untouched here: they are guest-accessible
  /// and the settings page already owns their wipe (same UX-043 lane).
  Future<void> _clearLocalSnapshots() async {
    final addressClear = _localAddressRepository?.clear();
    if (addressClear != null) {
      final result = await addressClear;
      if (result case Failure(:final error)) {
        Log.w('Address snapshot clear failed: ${error.message}',
            category: LogCategory.auth);
      }
    }
    // Contained like the address clear above: a platform failure wiping
    // the orders snapshot must never abort signOut or deleteAccount —
    // those flows still need to reach emit(unauthenticated).
    try {
      await _storefrontPersistence?.clearOrders();
    } catch (_) {
      Log.w('clearOrders failed during snapshot wipe',
          category: LogCategory.auth);
    }
  }

  void _listenToAuthChanges() {
    _authSubscription =
        _authRepository.authStateChanges.listen((outcome) async {
      if (outcome != null) {
        await _loadProfile(outcome.userId);
      } else {
        // signedOut — clear local state.
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearProfile: true,
        ));
      }
    });
  }

  Future<void> _applyAuthResult(Result<AuthOutcome> result) async {
    switch (result) {
      case Success(:final value):
        switch (value) {
          case Authenticated(:final userId):
            await _loadProfile(userId);
          case ConfirmationRequired():
            // Account created, email confirmation pending — not signed in.
            emit(state.copyWith(status: AuthStatus.unauthenticated));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
        ));
    }
  }

  Future<void> _loadProfile(String userId) async {
    final result = await _profileRepository.readProfile(userId);
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          profile: value,
        ));
      case Failure(:final error):
        // Profile may not exist yet (race with the database trigger) or
        // the read failed. Either way the session is valid — authenticate
        // without a profile so the user isn't stuck. Log for diagnosis.
        Log.w('Profile load failed: ${error.message}',
            category: LogCategory.auth);
        emit(state.copyWith(status: AuthStatus.authenticated));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
