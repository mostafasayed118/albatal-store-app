import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/shared/services/logger.dart';

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
  })  : _authRepository = authRepository,
        _profileRepository = profileRepository,
        super(const AuthState()) {
    _listenToAuthChanges();
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
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
    emit(state.copyWith(
      status: AuthStatus.unauthenticated,
      clearProfile: true,
    ));
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
