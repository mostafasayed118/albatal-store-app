import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';

/// Unsigned-in stubs for widget harnesses that pump pages which now
/// watch AuthCubit (home greeting shows the profile name).
class StubAuthRepository implements AuthRepository {
  @override
  Future<Result<Authenticated?>> checkSession() async => const Success(null);

  @override
  Future<Result<AuthOutcome>> signUp(
      {required String email,
      required String password,
      String? fullName}) async {
    return const Failure(AppError('stub'));
  }

  @override
  Future<Result<Authenticated>> signIn(
      {required String email, required String password}) async {
    return const Failure(AppError('stub'));
  }

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges =>
      const Stream<Authenticated?>.empty();
}

class StubProfileRepository implements ProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      const Success(null);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}
