import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';

import '../domain/entities/auth_outcome.dart';
import '../domain/repositories/auth_repository.dart';

/// Supabase-backed [AuthRepository].
///
/// Owns all Supabase auth interactions and translates [AuthException]
/// messages into user-safe [AppError]s at the data boundary so the
/// presentation layer never sees Supabase-specific strings. The
/// `_mapAuthError` table lives here per Clean Architecture C.1
/// ("mapping logic belongs in the data layer").
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<Authenticated?>> checkSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return const Success(null);
      return Success(Authenticated(session.user.id));
    } catch (e) {
      return Failure(AppError('Failed to read session', cause: e));
    }
  }

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName ?? ''},
      );
      if (response.user != null && response.session == null) {
        // Account created but email confirmation required — no session yet.
        return const Success(ConfirmationRequired());
      }
      if (response.user != null) {
        return Success(Authenticated(response.user!.id));
      }
      return Failure(AppError('Sign-up failed. Please try again.'));
    } on AuthException catch (e) {
      return Failure(AppError(_mapAuthError(e.message), cause: e));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred', cause: e));
    }
  }

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        return Failure(AppError('Sign-in failed. Please try again.'));
      }
      return Success(Authenticated(response.user!.id));
    } on AuthException catch (e) {
      return Failure(AppError(_mapAuthError(e.message), cause: e));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred', cause: e));
    }
  }

  @override
  Future<Result<void>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppError(_mapAuthError(e.message), cause: e));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred', cause: e));
    }
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppError(_mapAuthError(e.message), cause: e));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred', cause: e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to sign out', cause: e));
    }
  }

  @override
  Stream<Authenticated?> get authStateChanges =>
      _client.auth.onAuthStateChange.asyncExpand((data) {
        final session = data.session;
        if (session != null) {
          return Stream.value(Authenticated(session.user.id));
        }
        if (data.event == AuthChangeEvent.signedOut) {
          return Stream.value(null);
        }
        // Ignore other null-session events (e.g. userDeleted, passwordRecovery
        // without a session) to mirror the original cubit behavior, which
        // only reacted to signedOut.
        return const Stream<Authenticated?>.empty();
      });

  /// Map Supabase auth error messages to user-safe text.
  ///
  /// Lives in the data layer so the presentation cubit only ever sees
  /// [AppError.message] — never Supabase-specific strings. Add new
  /// mappings here as new error cases are discovered.
  String _mapAuthError(String message) {
    switch (message) {
      case 'Invalid login credentials':
        return 'Invalid email or password';
      case 'Email not confirmed':
        return 'Please verify your email address first';
      case 'User already registered':
        return 'An account with this email already exists';
      case 'Password should be at least 6 characters':
        return 'Password must be at least 6 characters';
      default:
        return message;
    }
  }
}
