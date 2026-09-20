import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/failure_codes.dart';
import '../../../core/error/result.dart';

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
  SupabaseAuthRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<Authenticated?>> checkSession() => Result.guard(() async {
        final session = _client.auth.currentSession;
        if (session == null) return null;
        return Authenticated(session.user.id);
      }, 'Failed to read session', code: kFailureLoad);

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
      return const Failure(AppError('Sign-up failed. Please try again.',
          code: kFailureSignUpFailed));
    } on AuthException catch (e) {
      final mapped = _mapAuthError(e.message);
      return Failure(AppError(mapped.message, cause: e, code: mapped.code));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred',
          cause: e, code: kFailureUnexpected));
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
        return const Failure(AppError('Sign-in failed. Please try again.',
            code: kFailureSignInFailed));
      }
      return Success(Authenticated(response.user!.id));
    } on AuthException catch (e) {
      final mapped = _mapAuthError(e.message);
      return Failure(AppError(mapped.message, cause: e, code: mapped.code));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred',
          cause: e, code: kFailureUnexpected));
    }
  }

  @override
  Future<Result<void>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Success(null);
    } on AuthException catch (e) {
      final mapped = _mapAuthError(e.message);
      return Failure(AppError(mapped.message, cause: e, code: mapped.code));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred',
          cause: e, code: kFailureUnexpected));
    }
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return const Success(null);
    } on AuthException catch (e) {
      final mapped = _mapAuthError(e.message);
      return Failure(AppError(mapped.message, cause: e, code: mapped.code));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred',
          cause: e, code: kFailureUnexpected));
    }
  }

  @override
  Future<Result<void>> signOut() => Result.guard<void>(() async {
        await _client.auth.signOut();
      }, 'Failed to sign out');

  @override
  Future<Result<void>> deleteAccount({required String email}) async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        return const Failure(AppError(
            'Your session expired. Please sign in again.',
            code: kFailureSessionExpired));
      }
      // The edge function re-verifies the JWT and compares [email] against
      // the account email before deleting with the service role (UX-043).
      await _client.functions.invoke(
        'delete-account',
        body: {'userId': session.user.id, 'email': email},
      );
      return const Success(null);
    } on FunctionException catch (e) {
      // `details` carries the parsed JSON body, e.g. { message: '...' }.
      final serverMessage = switch (e.details) {
        {'message': final String m} => m,
        _ => e.reasonPhrase ?? '',
      };
      final mapped = _mapDeleteError(serverMessage);
      return Failure(AppError(mapped.message, cause: e, code: mapped.code));
    } catch (e) {
      return Failure(AppError('An unexpected error occurred',
          cause: e, code: kFailureUnexpected));
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

  /// Map Supabase auth error messages to a user-safe message **and** its code.
  ///
  /// Lives in the data layer so the presentation cubit only ever sees
  /// [AppError.message] — never Supabase-specific strings. Add new
  /// mappings here as new error cases are discovered.
  ///
  /// The code is what the UI localizes on (audit 2026-09-19, sweep part 32);
  /// the English message stays as fail-soft text for logs and for any caller
  /// that has no localization available.
  ({String code, String message}) _mapAuthError(String message) {
    switch (message) {
      case 'Invalid login credentials':
        return (
          code: kAuthInvalidCredentials,
          message: 'Invalid email or password'
        );
      case 'Email not confirmed':
        return (
          code: kAuthEmailUnconfirmed,
          message: 'Please verify your email address first'
        );
      case 'User already registered':
        return (
          code: kAuthEmailInUse,
          message: 'An account with this email already exists'
        );
      // GoTrue's floor is 8 (verified live 2026-09-13); keep matching the
      // legacy 6-char provider string so older server responses still map
      // to the current user-safe copy instead of the generic fallback.
      case 'Password should be at least 6 characters':
      case 'Password should be at least 8 characters':
        return (
          code: kAuthWeakPassword,
          message: 'Password must be at least 8 characters'
        );
      default:
        // Never surface unknown provider strings — callers already attach
        // the original exception as AppError.cause for diagnostics.
        return (
          code: kFailureUnexpected,
          message: 'An unexpected error occurred'
        );
    }
  }

  /// Map delete-account refusal messages from the edge function to a user-safe
  /// message and its code. Unknown messages collapse to a generic pair.
  ({String code, String message}) _mapDeleteError(String message) {
    final m = message.toLowerCase();
    if (m.contains('email does not match')) {
      return (
        code: kDeleteEmailMismatch,
        message: 'The email does not match this account'
      );
    }
    if (m.contains('admin')) {
      return (
        code: kDeleteAdminBlocked,
        message: 'Admin accounts cannot be deleted in the app'
      );
    }
    if (m.contains('cannot delete another')) {
      return (
        code: kDeleteNotOwner,
        message: 'You can only delete your own account'
      );
    }
    if (m.contains('session expired') ||
        m.contains('authentication required')) {
      return (
        code: kFailureSessionExpired,
        message: 'Your session expired. Please sign in again.'
      );
    }
    return (
      code: kDeleteFailed,
      message: 'Account deletion failed. Please try again.'
    );
  }
}
