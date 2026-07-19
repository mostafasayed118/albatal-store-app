import 'dart:async';

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-rolled stub matching the project's existing test style
/// (catalog_cubit_test.dart, settings_cubit_test.dart). The declared
/// `mocktail` dev dep is intentionally unused to stay consistent.
class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository({
    Future<Result<Authenticated?>> Function()? checkSession,
    Future<Result<AuthOutcome>> Function({
      required String email,
      required String password,
      String? fullName,
    })? signUp,
    Future<Result<Authenticated>> Function({
      required String email,
      required String password,
    })? signIn,
    Future<Result<void>> Function(String email)? resetPassword,
    Future<Result<void>> Function(String password)? updatePassword,
    Future<Result<void>> Function()? signOut,
    Stream<Authenticated?> Function()? authStateChanges,
  })  : _checkSession = checkSession,
        _signUp = signUp,
        _signIn = signIn,
        _resetPassword = resetPassword,
        _updatePassword = updatePassword,
        _signOut = signOut,
        _authStateChanges = authStateChanges;

  final Future<Result<Authenticated?>> Function()? _checkSession;
  final Future<Result<AuthOutcome>> Function({
    required String email,
    required String password,
    String? fullName,
  })? _signUp;
  final Future<Result<Authenticated>> Function({
    required String email,
    required String password,
  })? _signIn;
  final Future<Result<void>> Function(String email)? _resetPassword;
  final Future<Result<void>> Function(String password)? _updatePassword;
  final Future<Result<void>> Function()? _signOut;
  final Stream<Authenticated?> Function()? _authStateChanges;

  @override
  Future<Result<Authenticated?>> checkSession() async {
    if (_checkSession != null) return await _checkSession();
    return const Success(null);
  }

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (_signUp != null) {
      return await _signUp(email: email, password: password, fullName: fullName);
    }
    return const Success(ConfirmationRequired());
  }

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async {
    if (_signIn != null) return await _signIn(email: email, password: password);
    return const Success(Authenticated('user-1'));
  }

  @override
  Future<Result<void>> resetPassword(String email) async {
    if (_resetPassword != null) return await _resetPassword(email);
    return const Success(null);
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) async {
    if (_updatePassword != null) return await _updatePassword(newPassword);
    return const Success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    if (_signOut != null) return await _signOut();
    return const Success(null);
  }

  @override
  Stream<Authenticated?> get authStateChanges =>
      _authStateChanges != null ? _authStateChanges() : const Stream<Authenticated?>.empty();
}

class _StubProfileRepository implements ProfileRepository {
  _StubProfileRepository({this.profile});
  final Profile? profile;

  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(profile);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

void main() {
  group('AuthCubit', () {
    late _StubProfileRepository profileRepo;
    late Profile sampleProfile;

    setUp(() {
      sampleProfile = const Profile(id: 'user-1', fullName: 'Ahmed');
      profileRepo = _StubProfileRepository(profile: sampleProfile);
    });

    test('initial state is AuthStatus.initial', () {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: profileRepo,
      );
      expect(cubit.state.status, AuthStatus.initial);
      cubit.close();
    });

    test('checkSession with no session sets unauthenticated', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          checkSession: () async => const Success(null),
        ),
        profileRepository: profileRepo,
      );
      await cubit.checkSession();
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.profile, isNull);
      await cubit.close();
    });

    test('checkSession with session loads profile and authenticates',
        () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          checkSession: () async => const Success(Authenticated('user-1')),
        ),
        profileRepository: _StubProfileRepository(
          profile: const Profile(id: 'user-1', fullName: 'Sara'),
        ),
      );
      await cubit.checkSession();
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.profile?.fullName, 'Sara');
      await cubit.close();
    });

    test('checkSession failure sets failure status with message', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          checkSession: () async =>
              const Failure(AppError('Failed to read session')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.checkSession();
      expect(cubit.state.status, AuthStatus.failure);
      expect(cubit.state.errorMessage, 'Failed to read session');
      await cubit.close();
    });

    test('signIn success authenticates and loads profile', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signIn: ({required email, required password}) async =>
              const Success(Authenticated('user-1')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.signIn(email: 'a@b.com', password: 'pw');
      // After the await completes the state should be authenticated.
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.profile?.fullName, 'Ahmed');
      await cubit.close();
    });

    test('signIn failure sets failure status with mapped message', () async {
      // The repository is responsible for mapping Supabase error strings
      // to user-safe text. The cubit only surfaces AppError.message.
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signIn: ({required email, required password}) async =>
              const Failure(AppError('Invalid email or password')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.signIn(email: 'a@b.com', password: 'wrong');
      expect(cubit.state.status, AuthStatus.failure);
      expect(cubit.state.errorMessage, 'Invalid email or password');
      expect(cubit.state.profile, isNull);
      await cubit.close();
    });

    test('signUp with confirmation required sets unauthenticated', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signUp: ({required email, required password, fullName}) async =>
              const Success(ConfirmationRequired()),
        ),
        profileRepository: profileRepo,
      );
      await cubit.signUp(email: 'a@b.com', password: 'pw', fullName: 'X');
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.profile, isNull);
      await cubit.close();
    });

    test('signUp with immediate session authenticates', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signUp: ({required email, required password, fullName}) async =>
              const Success(Authenticated('user-1')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.signUp(email: 'a@b.com', password: 'pw');
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.profile?.fullName, 'Ahmed');
      await cubit.close();
    });

    test('resetPassword success sets passwordRecovery', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: profileRepo,
      );
      await cubit.resetPassword('a@b.com');
      expect(cubit.state.status, AuthStatus.passwordRecovery);
      await cubit.close();
    });

    test('resetPassword failure sets failure status', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          resetPassword: (email) async =>
              const Failure(AppError('Rate limit exceeded')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.resetPassword('a@b.com');
      expect(cubit.state.status, AuthStatus.failure);
      expect(cubit.state.errorMessage, 'Rate limit exceeded');
      await cubit.close();
    });

    test('updatePassword success sets authenticated', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: profileRepo,
      );
      await cubit.updatePassword('newpw');
      expect(cubit.state.status, AuthStatus.authenticated);
      await cubit.close();
    });

    test('updatePassword failure sets failure status', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          updatePassword: (password) async =>
              const Failure(AppError('Password too weak')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.updatePassword('newpw');
      expect(cubit.state.status, AuthStatus.failure);
      expect(cubit.state.errorMessage, 'Password too weak');
      await cubit.close();
    });

    test('signOut sets unauthenticated and clears profile', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signIn: ({required email, required password}) async =>
              const Success(Authenticated('user-1')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.signIn(email: 'a@b.com', password: 'pw');
      expect(cubit.state.profile, isNotNull);
      await cubit.signOut();
      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.profile, isNull);
      await cubit.close();
    });

    test('clearError transitions failure to unauthenticated', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signIn: ({required email, required password}) async =>
              const Failure(AppError('bad')),
        ),
        profileRepository: profileRepo,
      );
      await cubit.signIn(email: 'a@b.com', password: 'pw');
      expect(cubit.state.status, AuthStatus.failure);
      cubit.clearError();
      expect(cubit.state.status, AuthStatus.unauthenticated);
      await cubit.close();
    });

    test('clearError is a no-op when not in failure state', () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: profileRepo,
      );
      cubit.clearError();
      expect(cubit.state.status, AuthStatus.initial);
      await cubit.close();
    });

    test('authStateChanges signedOut event clears authenticated state',
        () async {
      // Use a controller to push a synthetic signedOut event.
      final controller = StreamController<Authenticated?>();
      addTearDown(controller.close);

      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          signIn: ({required email, required password}) async =>
              const Success(Authenticated('user-1')),
          authStateChanges: () => controller.stream,
        ),
        profileRepository: profileRepo,
      );
      await cubit.signIn(email: 'a@b.com', password: 'pw');
      expect(cubit.state.status, AuthStatus.authenticated);

      // Push a signedOut event on the stream.
      controller.add(null);
      // Give the listener a turn to process.
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.profile, isNull);
      await cubit.close();
    });

    test('authStateChanges Authenticated event loads profile', () async {
      final controller = StreamController<Authenticated?>();
      addTearDown(controller.close);

      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(
          authStateChanges: () => controller.stream,
        ),
        profileRepository: profileRepo,
      );
      // Push a session-established event.
      controller.add(const Authenticated('user-1'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.profile?.fullName, 'Ahmed');
      await cubit.close();
    });
  });
}
