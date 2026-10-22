import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/data/supabase_auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

User _user([String id = 'user-1']) => User.fromJson({
      'id': id,
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    })!;

Session _session([String id = 'user-1']) => Session(
      accessToken: 'access-token',
      tokenType: 'bearer',
      user: _user(id),
    );

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockFunctionsClient functions;
  late SupabaseAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(UserAttributes(password: 'fallback'));
  });

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    functions = _MockFunctionsClient();
    when(() => client.auth).thenReturn(auth);
    when(() => client.functions).thenReturn(functions);
    repository = SupabaseAuthRepository(client: client);
  });

  group('checkSession', () {
    test('returns null when there is no current session', () async {
      when(() => auth.currentSession).thenReturn(null);

      final result = await repository.checkSession();

      final value =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(value, isNull);
    });

    test('maps the current session user id', () async {
      when(() => auth.currentSession).thenReturn(_session('session-user'));

      final result = await repository.checkSession();

      final value =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(value?.userId, 'session-user');
    });

    test('a throwing client degrades to a load failure', () async {
      when(() => auth.currentSession).thenThrow(Exception('boom'));

      final result = await repository.checkSession();

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureLoad);
      expect(error.message, 'Failed to read session');
    });
  });

  group('signUp', () {
    test('maps a session response to Authenticated', () async {
      when(() => auth.signUp(
                email: 'a@b.com',
                password: 'secret123',
                data: any(named: 'data'),
              ))
          .thenAnswer((_) async => AuthResponse(session: _session('new-user')));

      final result =
          await repository.signUp(email: 'a@b.com', password: 'secret123');

      final outcome =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(outcome, isA<Authenticated>());
      expect((outcome as Authenticated).userId, 'new-user');
    });

    test('maps a user without a session to ConfirmationRequired', () async {
      when(() => auth.signUp(
            email: 'a@b.com',
            password: 'secret123',
            data: any(named: 'data'),
          )).thenAnswer((_) async => AuthResponse(user: _user('pending-user')));

      final result =
          await repository.signUp(email: 'a@b.com', password: 'secret123');

      final outcome =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(outcome, isA<ConfirmationRequired>());
    });

    test('fails when the provider returns neither user nor session', () async {
      when(() => auth.signUp(
            email: 'a@b.com',
            password: 'secret123',
            data: any(named: 'data'),
          )).thenAnswer((_) async => AuthResponse());

      final result =
          await repository.signUp(email: 'a@b.com', password: 'secret123');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureSignUpFailed);
      expect(error.message, 'Sign-up failed. Please try again.');
    });

    test('maps provider auth errors to user-safe codes', () async {
      when(() => auth.signUp(
            email: 'a@b.com',
            password: 'secret123',
            data: any(named: 'data'),
          )).thenThrow(const AuthException('User already registered'));

      final result =
          await repository.signUp(email: 'a@b.com', password: 'secret123');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kAuthEmailInUse);
      expect(error.message, 'An account with this email already exists');
    });

    test('maps unexpected throws to the generic failure', () async {
      when(() => auth.signUp(
            email: 'a@b.com',
            password: 'secret123',
            data: any(named: 'data'),
          )).thenThrow(Exception('boom'));

      final result =
          await repository.signUp(email: 'a@b.com', password: 'secret123');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureUnexpected);
      expect(error.message, 'An unexpected error occurred');
    });
  });

  group('signIn', () {
    test('maps a successful password sign-in to Authenticated', () async {
      when(() =>
              auth.signInWithPassword(email: 'a@b.com', password: 'secret123'))
          .thenAnswer((_) async => AuthResponse(session: _session('user-9')));

      final result =
          await repository.signIn(email: 'a@b.com', password: 'secret123');

      final outcome =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(outcome.userId, 'user-9');
    });

    test('fails when the provider returns no user', () async {
      when(() =>
              auth.signInWithPassword(email: 'a@b.com', password: 'secret123'))
          .thenAnswer((_) async => AuthResponse());

      final result =
          await repository.signIn(email: 'a@b.com', password: 'secret123');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureSignInFailed);
      expect(error.message, 'Sign-in failed. Please try again.');
    });

    const mappings = <(String, String, String)>[
      (
        'Invalid login credentials',
        kAuthInvalidCredentials,
        'Invalid email or password'
      ),
      (
        'Email not confirmed',
        kAuthEmailUnconfirmed,
        'Please verify your email address first'
      ),
      (
        'User already registered',
        kAuthEmailInUse,
        'An account with this email already exists'
      ),
      (
        'Password should be at least 6 characters',
        kAuthWeakPassword,
        'Password must be at least 8 characters'
      ),
      (
        'Password should be at least 8 characters',
        kAuthWeakPassword,
        'Password must be at least 8 characters'
      ),
      (
        'Some brand new provider string',
        kFailureUnexpected,
        'An unexpected error occurred'
      ),
    ];

    for (final (providerMessage, code, message) in mappings) {
      test('maps "$providerMessage" to $code', () async {
        when(() => auth.signInWithPassword(email: 'a@b.com', password: 'pw'))
            .thenThrow(AuthException(providerMessage));

        final result =
            await repository.signIn(email: 'a@b.com', password: 'pw');

        final error =
            result.when(success: (_) => fail('unexpected'), failure: (e) => e);
        expect(error.code, code);
        expect(error.message, message);
      });
    }

    test('maps unexpected throws to the generic failure', () async {
      when(() => auth.signInWithPassword(email: 'a@b.com', password: 'pw'))
          .thenThrow(Exception('boom'));

      final result = await repository.signIn(email: 'a@b.com', password: 'pw');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureUnexpected);
    });
  });

  group('resetPassword', () {
    test('returns Success when the provider accepts the email', () async {
      when(() => auth.resetPasswordForEmail('a@b.com'))
          .thenAnswer((_) async {});

      final result = await repository.resetPassword('a@b.com');

      expect(result, isA<Success<void>>());
    });

    test('maps provider auth errors', () async {
      when(() => auth.resetPasswordForEmail('a@b.com'))
          .thenThrow(const AuthException('Email not confirmed'));

      final result = await repository.resetPassword('a@b.com');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kAuthEmailUnconfirmed);
    });

    test('maps unexpected throws to the generic failure', () async {
      when(() => auth.resetPasswordForEmail('a@b.com'))
          .thenThrow(Exception('boom'));

      final result = await repository.resetPassword('a@b.com');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureUnexpected);
    });
  });

  group('updatePassword', () {
    test('returns Success when the provider updates the user', () async {
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson({'id': 'user-1'}));

      final result = await repository.updatePassword('newpass123');

      expect(result, isA<Success<void>>());
      verify(() => auth.updateUser(any())).called(1);
    });

    test('maps provider auth errors', () async {
      when(() => auth.updateUser(any())).thenThrow(
          const AuthException('Password should be at least 6 characters'));

      final result = await repository.updatePassword('short');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kAuthWeakPassword);
    });

    test('maps unexpected throws to the generic failure', () async {
      when(() => auth.updateUser(any())).thenThrow(Exception('boom'));

      final result = await repository.updatePassword('newpass123');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureUnexpected);
    });
  });

  group('signOut', () {
    test('returns Success when the provider signs out', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result, isA<Success<void>>());
    });

    test('maps a provider throw to the generic failure', () async {
      when(() => auth.signOut()).thenThrow(Exception('boom'));

      final result = await repository.signOut();

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureUnexpected);
      expect(error.message, 'Failed to sign out');
    });
  });

  group('deleteAccount', () {
    Future<Result<void>> deleteWith(Object throwable) {
      when(() => auth.currentSession).thenReturn(_session('user-1'));
      when(() => functions.invoke('delete-account', body: any(named: 'body')))
          .thenThrow(throwable);
      return repository.deleteAccount(email: 'a@b.com');
    }

    test('refuses to call the function without a session', () async {
      when(() => auth.currentSession).thenReturn(null);

      final result = await repository.deleteAccount(email: 'a@b.com');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureSessionExpired);
      expect(error.message, 'Your session expired. Please sign in again.');
      verifyNever(
          () => functions.invoke('delete-account', body: any(named: 'body')));
    });

    test('invokes the edge function when a session exists', () async {
      when(() => auth.currentSession).thenReturn(_session('user-1'));
      when(() => functions.invoke('delete-account', body: any(named: 'body')))
          .thenAnswer((_) async => const FunctionResponse(status: 200));

      final result = await repository.deleteAccount(email: 'a@b.com');

      expect(result, isA<Success<void>>());
      verify(() => functions.invoke('delete-account', body: any(named: 'body')))
          .called(1);
    });

    const refusals = <(Object, String)>[
      (
        FunctionException(
          status: 400,
          details: {'message': 'Email does not match the account'},
        ),
        kDeleteEmailMismatch,
      ),
      (
        FunctionException(
          status: 403,
          details: {'message': 'Admin accounts cannot be deleted'},
        ),
        kDeleteAdminBlocked,
      ),
      (
        FunctionException(
          status: 403,
          details: {'message': 'You cannot delete another user'},
        ),
        kDeleteNotOwner,
      ),
      (
        FunctionException(
          status: 401,
          details: {'message': 'Session expired'},
        ),
        kFailureSessionExpired,
      ),
      (
        FunctionException(
          status: 401,
          details: {'message': 'Authentication required'},
        ),
        kFailureSessionExpired,
      ),
      (
        FunctionException(
          status: 500,
          details: {'message': 'Something exploded'},
        ),
        kDeleteFailed,
      ),
      (
        FunctionException(status: 403, reasonPhrase: 'admin forbidden'),
        kDeleteAdminBlocked,
      ),
      (
        FunctionException(status: 500),
        kDeleteFailed,
      ),
    ];

    for (final (throwable, code) in refusals) {
      test('maps a FunctionException to $code', () async {
        final result = await deleteWith(throwable);

        final error =
            result.when(success: (_) => fail('unexpected'), failure: (e) => e);
        expect(error.code, code);
      });
    }

    test('maps unexpected throws to the generic failure', () async {
      final result = await deleteWith(Exception('boom'));

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureUnexpected);
    });
  });

  group('authStateChanges', () {
    test('emits the user id for a session event', () async {
      when(() => auth.onAuthStateChange)
          .thenAnswer((_) => Stream<AuthState>.value(
                AuthState(AuthChangeEvent.signedIn, _session('stream-user')),
              ));

      final value = await repository.authStateChanges.first;

      expect(value?.userId, 'stream-user');
    });

    test('emits null for a signed-out event', () async {
      when(() => auth.onAuthStateChange).thenAnswer((_) =>
          Stream<AuthState>.value(
              const AuthState(AuthChangeEvent.signedOut, null)));

      final value = await repository.authStateChanges.first;

      expect(value, isNull);
    });

    test('ignores null-session events other than signedOut', () async {
      when(() => auth.onAuthStateChange).thenAnswer((_) =>
          Stream<AuthState>.value(
              const AuthState(AuthChangeEvent.passwordRecovery, null)));

      await expectLater(repository.authStateChanges, emitsDone);
    });
  });
}
