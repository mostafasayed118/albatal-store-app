import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthState;

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';

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
    required SupabaseClient client,
    required ProfileRepository profileRepository,
  })  : _client = client,
        _profileRepository = profileRepository,
        super(const AuthState()) {
    _listenToAuthChanges();
  }

  final SupabaseClient _client;
  final ProfileRepository _profileRepository;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  /// Check for an existing session on app launch.
  Future<void> checkSession() async {
    emit(state.copyWith(status: AuthStatus.checkingSession));
    final session = _client.auth.currentSession;
    if (session != null) {
      await _loadProfile(session.user.id);
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  /// Sign up with email and password.
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName ?? ''},
      );
      if (response.user != null && response.session == null) {
        // Email confirmation required — user is created but not yet signed in
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      } else if (response.session != null) {
        await _loadProfile(response.user!.id);
      }
    } on AuthException catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: _mapAuthError(e)));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: 'An unexpected error occurred'));
    }
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null && response.user != null) {
        await _loadProfile(response.user!.id);
      }
    } on AuthException catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: _mapAuthError(e)));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: 'An unexpected error occurred'));
    }
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await _client.auth.resetPasswordForEmail(email);
      emit(state.copyWith(status: AuthStatus.passwordRecovery));
    } on AuthException catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: _mapAuthError(e)));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: 'An unexpected error occurred'));
    }
  }

  /// Update password (called from reset-password screen).
  Future<void> updatePassword(String newPassword) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      emit(state.copyWith(status: AuthStatus.authenticated));
    } on AuthException catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: _mapAuthError(e)));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.failure, errorMessage: 'An unexpected error occurred'));
    }
  }

  /// Update profile fields.
  Future<void> updateProfile({String? fullName, String? phone}) async {
    if (state.profile == null) return;
    final updated = state.profile!.copyWith(
      fullName: fullName,
      phone: phone,
    );
    await _profileRepository.upsertProfile(updated);
    emit(state.copyWith(profile: updated));
  }

  /// Sign out and clear all account state.
  Future<void> signOut() async {
    await _client.auth.signOut();
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
    _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _loadProfile(session.user.id);
      } else if (data.event == AuthChangeEvent.signedOut) {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearProfile: true,
        ));
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await _profileRepository.readProfile(userId);
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
      ));
    } catch (e) {
      // Profile may not exist yet (race with trigger) — still authenticated
      emit(state.copyWith(status: AuthStatus.authenticated));
    }
  }

  String _mapAuthError(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password';
      case 'Email not confirmed':
        return 'Please verify your email address first';
      case 'User already registered':
        return 'An account with this email already exists';
      case 'Password should be at least 6 characters':
        return 'Password must be at least 6 characters';
      default:
        return e.message;
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
