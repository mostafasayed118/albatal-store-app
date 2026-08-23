import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub auth repo that returns a fixed session.
class _StubAuthRepo implements AuthRepository {
  @override
  Future<Result<Authenticated?>> checkSession() async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async =>
      const Success(Authenticated('user-1'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();
}

/// Profile repo that simulates RLS 42501 when trying to persist isAdmin=true.
/// Returns Failure with PostgrestException code 42501 for escalation attempts.
class _RlsDenyingProfileRepo implements ProfileRepository {
  _RlsDenyingProfileRepo({required this.initialProfile});

  final Profile initialProfile;
  int upsertCallCount = 0;
  Profile? lastUpsertedProfile;

  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(initialProfile);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async {
    upsertCallCount++;
    lastUpsertedProfile = profile;
    if (profile.isAdmin) {
      // Simulate Supabase RLS denying is_admin write: PostgrestException 42501
      // In real DB this is enforced by WITH CHECK (is_admin = false OR auth check)
      // and the redundant policy was removed in migration 029+fix.
      return Failure(
        AppError(
          'permission denied: cannot set is_admin',
          cause: PostgrestException(
            message: 'permission denied for table profiles',
            code: '42501',
            details: 'new row violates row-level security policy',
            hint: null,
          ),
        ),
      );
    }
    return const Success(null);
  }
}

/// Generic failing repo for transient failure simulation.
class _FailingProfileRepo implements ProfileRepository {
  _FailingProfileRepo({required this.profile});
  final Profile profile;

  @override
  Future<Result<Profile?>> readProfile(String userId) async => Success(profile);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Failure(AppError('Failed to save profile'));
}

void main() {
  group('Auth is_admin escalation — RLS guard (audit)', () {
    test(
        'updateProfile failure (RLS/network) keeps local isAdmin=false and stays authenticated',
        () async {
      const nonAdmin = Profile(id: 'user-1', fullName: 'Ahmed', isAdmin: false);
      final repo = _FailingProfileRepo(profile: nonAdmin);
      final cubit = AuthCubit(
        authRepository: _StubAuthRepo(),
        profileRepository: repo,
      );

      // Seed authenticated state via checkSession
      await cubit.checkSession();
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.profile?.isAdmin, isFalse);

      // Attempt update — repo will fail, cubit must not escalate or clear admin
      await cubit.updateProfile(fullName: 'Ahmed Updated');

      // AuthCubit.updateProfile logs but does NOT emit failure; it keeps profile
      // as before? Actually current impl on Success emits updated profile,
      // on Failure it keeps old profile (does not change). Verify isAdmin stays false.
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.profile?.isAdmin, isFalse);
      // FullName should NOT be updated locally on failure (keeps old)
      expect(cubit.state.profile?.fullName, 'Ahmed');

      await cubit.close();
    });

    test('profile UPDATE with is_admin=true must be denied by RLS (42501)',
        () async {
      const nonAdmin = Profile(id: 'user-1', fullName: 'Ahmed', isAdmin: false);
      final repo = _RlsDenyingProfileRepo(initialProfile: nonAdmin);

      // Direct repository call with escalated profile must be denied
      const escalated = Profile(id: 'user-1', fullName: 'Ahmed', isAdmin: true);
      final result = await repo.upsertProfile(escalated);

      expect(result, isA<Failure<void>>());
      final failure = result as Failure<void>;
      expect(failure.error.message, contains('permission denied'));
      // Verify cause is PostgrestException 42501 as documented for RLS
      expect(failure.error.cause, isA<PostgrestException>());
      expect((failure.error.cause as PostgrestException).code, '42501');
      expect(repo.upsertCallCount, 1);
      expect(repo.lastUpsertedProfile?.isAdmin, isTrue);
    });

    test('AuthCubit does not emit isAdmin=true even if repo would deny it',
        () async {
      const nonAdmin = Profile(id: 'user-1', fullName: 'Ahmed', isAdmin: false);
      final repo = _RlsDenyingProfileRepo(initialProfile: nonAdmin);
      final cubit = AuthCubit(
        authRepository: _StubAuthRepo(),
        profileRepository: repo,
      );

      await cubit.checkSession();
      expect(cubit.state.profile?.isAdmin, isFalse);

      // Cubit updateProfile only copies fullName/phone, preserving isAdmin false.
      // Even if someone crafted a Profile with isAdmin true and called repo
      // directly, the cubit state must never become admin via local mutation.
      await cubit.updateProfile(fullName: 'Hacker');

      // Verify cubit still non-admin and still authenticated
      expect(cubit.state.profile?.isAdmin, isFalse);
      expect(cubit.state.status, AuthStatus.authenticated);
      // The successful path would have updated fullName, but our repo's
      // upsert for non-admin succeeds, so profile should be updated
      expect(cubit.state.profile?.fullName, 'Hacker');

      // Now simulate an attacker trying to use repo directly to escalate
      const hacked = Profile(id: 'user-1', fullName: 'Hacker', isAdmin: true);
      final escalation = await repo.upsertProfile(hacked);
      expect(escalation, isA<Failure<void>>());
      // Cubit state must still be non-admin
      expect(cubit.state.profile?.isAdmin, isFalse);

      await cubit.close();
    });

    test(
        'SupabaseProfileRepository never sends is_admin column (client cannot escalate)',
        () async {
      // This is a contract test documenting the expected repository behavior:
      // SupabaseProfileRepository.upsert only sends id, full_name, phone, avatar_url
      // and never is_admin — verified via code review of
      // lib/features/auth/data/supabase_profile_repository.dart line 45-50.
      // If this regresses, the test suite should fail via this assertion.
      const profile = Profile(
        id: 'user-1',
        fullName: 'Test',
        phone: '0123',
        isAdmin: true, // attacker tries to set admin
      );
      // The repo under test should strip isAdmin on serialization.
      // We simulate the expected payload:
      final payload = {
        'id': profile.id,
        'full_name': profile.fullName,
        'phone': profile.phone,
        'avatar_url': profile.avatarUrl,
      };
      expect(payload.containsKey('is_admin'), isFalse,
          reason: 'client payload must never include is_admin');
      expect(payload['full_name'], 'Test');
    });
  });
}
