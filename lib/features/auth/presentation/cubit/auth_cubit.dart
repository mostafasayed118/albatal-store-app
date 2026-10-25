import 'dart:async';

import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/logger.dart';
import '../../../addresses/addresses.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/order_snapshot_port.dart';
import '../../domain/repositories/profile_repository.dart';

import 'auth_state.dart';

export 'auth_state.dart';

part 'parts/auth_snapshot_wipe.dart';

// ─── Cubit ─────────────────────────────────────────────────

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
    AddressRepository? addressRepository,
    OrderSnapshotPort? orderSnapshots,
  })  : _authRepository = authRepository,
        _profileRepository = profileRepository,
        _addressRepository = addressRepository,
        _orderSnapshots = orderSnapshots,
        super(const AuthState()) {
    _listenToAuthChanges();
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  /// Device-local stores wiped on sign-out / account deletion so no
  /// address or order PII survives on the device (audit S9). Depend on
  /// the domain abstractions only (audit P1) — concretes are wired
  /// exclusively at the composition root (`app.dart`). Optional so the
  /// wipe is a no-op when absent (e.g. focused cubit tests).
  final AddressRepository? _addressRepository;
  final OrderSnapshotPort? _orderSnapshots;
  StreamSubscription<Authenticated?>? _authSubscription;

  /// Monotonic token for the current auth lifecycle. Bumped on every auth
  /// event and on explicit sign-out / account deletion; async work captures
  /// it and drops its emit when a newer transition superseded it. Without
  /// this, a profile read that completes after the user signed out emitted
  /// `authenticated` for the old user (live-found 2026-10-24).
  int _authGeneration = 0;

  /// Check for an existing session on app launch.
  Future<void> checkSession() async {
    final generation = _authGeneration;
    emit(state.copyWith(status: AuthStatus.checkingSession));
    final result = await _authRepository.checkSession();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        if (value != null) {
          await _loadProfile(value.userId, generation);
        } else {
          if (generation != _authGeneration) return;
          emit(state.copyWith(status: AuthStatus.unauthenticated));
        }
      case Failure(:final error):
        if (generation != _authGeneration) return;
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  /// Sign up with email and password.
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    // Invalidate any profile read still in flight for a previous account:
    // a new sign-up must never be overwritten by an older authenticated emit.
    final generation = ++_authGeneration;
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    await _applyAuthResult(result, generation);
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // Invalidate any profile read still in flight for a previous account.
    final generation = ++_authGeneration;
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.signIn(
      email: email,
      password: password,
    );
    await _applyAuthResult(result, generation);
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
          errorCode: error.code,
        ));
    }
  }

  /// Update password (called from reset-password screen).
  Future<void> updatePassword(String newPassword) async {
    final generation = _authGeneration;
    emit(state.copyWith(status: AuthStatus.authenticating));
    final result = await _authRepository.updatePassword(newPassword);
    if (isClosed || generation != _authGeneration) return;
    switch (result) {
      case Success():
        emit(state.copyWith(status: AuthStatus.authenticated));
      case Failure(:final error):
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  /// Update profile fields.
  Future<void> updateProfile({String? fullName, String? phone}) async {
    if (state.profile == null) return;
    final generation = _authGeneration;
    final updated = state.profile!.copyWith(
      fullName: fullName,
      phone: phone,
    );
    final result = await _profileRepository.upsertProfile(updated);
    // A sign-out during the write clears the profile; never restore it.
    if (isClosed || generation != _authGeneration) return;
    switch (result) {
      case Success():
        emit(state.copyWith(profile: updated, errorMessage: null));
      case Failure(:final error):
        Log.w('Profile save failed: ${error.message}',
            category: LogCategory.auth);
        // Surface to UI via errorMessage while staying authenticated;
        // do NOT emit the unpersisted edit (state keeps the last saved
        // profile so a retry shows honest data).
        emit(state.copyWith(errorMessage: error.message));
    }
  }

  /// Sign out and clear all account state.
  ///
  /// Server failure still signs out locally (the session is dead to the
  /// user) but is logged; snapshot-clear failures are retried once via
  /// [AuthSnapshotWipe.clearLocalSnapshots] so no address/order PII survives.
  Future<void> signOut() async {
    final generation = ++_authGeneration;
    final result = await _authRepository.signOut();
    if (result case Failure(:final error)) {
      Log.w('Sign-out server failure: ${error.message}',
          category: LogCategory.auth);
    }
    await clearLocalSnapshots();
    // A later auth event (or a new sign-in) supersedes this emit; the
    // signedOut stream listener owns the state transition in that case.
    if (isClosed || generation != _authGeneration) return;
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
        final generation = ++_authGeneration;
        await _authRepository.signOut();
        await clearLocalSnapshots();
        if (isClosed || generation != _authGeneration) {
          return const Success(null);
        }
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

  void _listenToAuthChanges() {
    _authSubscription =
        _authRepository.authStateChanges.listen((outcome) async {
      final generation = ++_authGeneration;
      if (outcome != null) {
        await _loadProfile(outcome.userId, generation);
      } else {
        // signedOut — clear local state. This event also covers
        // SERVER-driven sign-outs (refresh-token failure/revocation), so
        // the same PII wipe as explicit [signOut] applies (audit
        // 2026-09-21): without it the on-device address book and order
        // snapshots survived a revoked session. Double-wiping when the
        // user also tapped sign out is harmless — the clears are
        // idempotent and never abort on failure.
        await clearLocalSnapshots();
        if (isClosed || generation != _authGeneration) return;
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearProfile: true,
        ));
      }
    });
  }

  Future<void> _applyAuthResult(
    Result<AuthOutcome> result,
    int generation,
  ) async {
    switch (result) {
      case Success(:final value):
        switch (value) {
          case Authenticated(:final userId):
            await _loadProfile(userId, generation);
          case ConfirmationRequired():
            // Account created, email confirmation pending — not signed in.
            if (isClosed || generation != _authGeneration) return;
            emit(state.copyWith(status: AuthStatus.unauthenticated));
        }
      case Failure(:final error):
        if (isClosed || generation != _authGeneration) return;
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  /// Reads the profile and authenticates. [generation] is the auth token
  /// captured when the initiating operation started; a mismatch after the
  /// await means a newer auth event (e.g. sign-out) superseded this read,
  /// so the stale result is dropped instead of resurrecting the session.
  Future<void> _loadProfile(String userId, int generation) async {
    final result = await _profileRepository.readProfile(userId);
    if (isClosed || generation != _authGeneration) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          profile: value,
          userId: userId,
        ));
      case Failure(:final error):
        // Profile may not exist yet (race with the database trigger) or
        // the read failed. Either way the session is valid — authenticate
        // without a profile so the user isn't stuck. Log for diagnosis.
        Log.w('Profile load failed: ${error.message}',
            category: LogCategory.auth);
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          userId: userId,
        ));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
