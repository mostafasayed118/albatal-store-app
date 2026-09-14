import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_error.dart';
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
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<Authenticated?>> checkSession() =>
      Result.guard<Authenticated?>(() async {
        final session = _client.auth.currentSession;
        if (session == null) return null;
        return Authenticated(session.user.id);
      }, 'Failed to read session');

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await Result.guard(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName ?? ''},
      ),
      'An unexpected error occurred',
      onError: _mapThrown,
    );
    return response.when(
      success: (r) {
        if (r.user != null && r.session == null) {
          // Account created but email confirmation required — no session yet.
          return const Success<AuthOutcome>(ConfirmationRequired());
        }
        if (r.user != null) {
          return Success<AuthOutcome>(Authenticated(r.user!.id));
        }
        return const Failure<AuthOutcome>(
            AppError('Sign-up failed. Please try again.'));
      },
      failure: (error) => Failure<AuthOutcome>(error),
    );
  }

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await Result.guard(
      () => _client.auth.signInWithPassword(
        email: email,
        password: password,
      ),
      'An unexpected error occurred',
      onError: _mapThrown,
    );
    return response.when(
      success: (r) => r.user == null
          ? const Failure<Authenticated>(
              AppError('Sign-in failed. Please try again.'))
          : Success<Authenticated>(Authenticated(r.user!.id)),
      failure: (error) => Failure<Authenticated>(error),
    );
  }

  @override
  Future<Result<void>> resetPassword(String email) => Result.guard(
        () => _client.auth.resetPasswordForEmail(email),
        'An unexpected error occurred',
        onError: _mapThrown,
      );

  @override
  Future<Result<void>> updatePassword(String newPassword) => Result.guard(
        () => _client.auth.updateUser(UserAttributes(password: newPassword)),
        'An unexpected error occurred',
        onError: _mapThrown,
      );

  @override
  Future<Result<void>> signOut() =>
      Result.guard(() => _client.auth.signOut(), 'Failed to sign out');

  @override
  Future<Result<void>> deleteAccount({required String email}) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return const Failure(
          AppError('Your session expired. Please sign in again.'));
    }
    // The edge function re-verifies the JWT and compares [email] against
    // the account email before deleting with the service role (UX-043).
    return Result.guard(
      () => _client.functions.invoke(
        'delete-account',
        body: {'userId': session.user.id, 'email': email},
      ),
      'An unexpected error occurred',
      onError: _mapDeleteThrown,
    );
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
        // Never surface unknown provider strings — callers already attach
        // the original exception as AppError.cause for diagnostics.
        return 'An unexpected error occurred';
    }
  }

  /// Map delete-account refusal messages from the edge function to
  /// user-safe text. Unknown messages collapse to a generic string.
  String _mapDeleteError(String message) {
    final m = message.toLowerCase();
    if (m.contains('email does not match')) {
      return 'The email does not match this account';
    }
    if (m.contains('admin')) {
      return 'Admin accounts cannot be deleted in the app';
    }
    if (m.contains('cannot delete another')) {
      return 'You can only delete your own account';
    }
    if (m.contains('session expired') ||
        m.contains('authentication required')) {
      return 'Your session expired. Please sign in again.';
    }
    return 'Account deletion failed. Please try again.';
  }

  /// [Result.guard] error-mapper: [AuthException] messages go through
  /// [_mapAuthError]; anything else collapses to the generic string.
  AppError _mapThrown(Object e, StackTrace st) => AppError(
        e is AuthException
            ? _mapAuthError(e.message)
            : 'An unexpected error occurred',
        cause: e,
        stackTrace: st,
      );

  /// [Result.guard] error-mapper for the delete-account edge function.
  /// `details` carries the parsed JSON body, e.g. { message: '...' }.
  AppError _mapDeleteThrown(Object e, StackTrace st) {
    final serverMessage = switch (e) {
      FunctionException(details: {'message': final String m}) => m,
      FunctionException f => f.reasonPhrase ?? '',
      _ => '',
    };
    return AppError(_mapDeleteError(serverMessage), cause: e, stackTrace: st);
  }
}
