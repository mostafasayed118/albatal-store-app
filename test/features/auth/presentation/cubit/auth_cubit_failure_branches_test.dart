import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final class _AuthRepository implements AuthRepository {
  @override
  Future<Result<void>> completeOAuthCallback(Uri uri) async =>
      const Success(null);

  Result<Authenticated?> session = const Success(null);
  Result<void> signOutResult = const Success(null);

  @override
  Future<Result<Authenticated?>> checkSession() async => session;

  @override
  Future<Result<AuthOutcome>> signUp(
          {required String email,
          required String password,
          String? fullName}) async =>
      const Success(ConfirmationRequired());

  @override
  Future<Result<Authenticated>> signIn(
          {required String email, required String password}) async =>
      const Success(Authenticated('u1'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => signOutResult;

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();
}

final class _ProfileRepository implements ProfileRepository {
  Result<Profile?> readResult = const Success(null);

  @override
  Future<Result<Profile?>> readProfile(String userId) async => readResult;

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

void main() {
  test('a failed server sign-out still signs out locally', () async {
    final authRepository = _AuthRepository()
      ..signOutResult = const Failure(AppError('offline'));
    final cubit = AuthCubit(
      authRepository: authRepository,
      profileRepository: _ProfileRepository(),
    );
    addTearDown(cubit.close);

    await cubit.signOut();

    expect(cubit.state.status, AuthStatus.unauthenticated);
    expect(cubit.state.profile, isNull);
  });

  test('a failed profile load still authenticates the valid session', () async {
    final authRepository = _AuthRepository()
      ..session = const Success(Authenticated('u1'));
    final profiles = _ProfileRepository()
      ..readResult = const Failure(AppError('profile missing'));
    final cubit = AuthCubit(
      authRepository: authRepository,
      profileRepository: profiles,
    );
    addTearDown(cubit.close);

    await cubit.checkSession();

    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.userId, 'u1');
    expect(cubit.state.profile, isNull);
  });
}
