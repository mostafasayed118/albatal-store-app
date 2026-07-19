import 'dart:async';

import 'package:al_batal_elite/core/error/result.dart';

import '../entities/auth_outcome.dart';

/// Abstraction for auth operations.
///
/// The data layer (SupabaseAuthRepository) implements this and is
/// responsible for translating Supabase auth errors into user-safe
/// [AppError]s at the boundary. The presentation layer (AuthCubit) only
/// ever sees [Result] and [AppError.message] — never Supabase-specific
/// types or strings.
abstract interface class AuthRepository {
  /// Check for an existing session on app launch.
  ///
  /// Returns `Success(Authenticated(userId))` if a session exists, or
  /// `Success(null)` if no session is present (not a failure).
  Future<Result<Authenticated?>> checkSession();

  /// Sign up with email/password. Returns `Success(ConfirmationRequired)`
  /// when the account is created but email confirmation is pending.
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  });

  /// Sign in with email/password.
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  });

  /// Send a password reset email.
  Future<Result<void>> resetPassword(String email);

  /// Update the current user's password (called from reset-password screen).
  Future<Result<void>> updatePassword(String newPassword);

  /// Sign out and clear the server-side session.
  Future<Result<void>> signOut();

  /// Stream of meaningful auth state changes.
  ///
  /// Emits `Authenticated(userId)` when a session is established (sign-in,
  /// sign-up with session, token refresh with a session) and `null` when
  /// the user signs out. Other auth events with no session are filtered
  /// out. The repository owns the underlying auth-state subscription
  /// and translates it into a domain-shaped stream.
  Stream<Authenticated?> get authStateChanges;
}
