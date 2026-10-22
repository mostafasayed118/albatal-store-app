import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/order_snapshot_port.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  Future<Result<Authenticated?>> checkSession() async => const Success(null);

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async =>
      const Success(ConfirmationRequired());

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
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges =>
      const Stream<Authenticated?>.empty();
}

class _StubProfileRepository implements ProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      const Success(null);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

/// Order-snapshot double that always throws, so the late fire-and-forget
/// retry fails too and its error has to be swallowed.
class _AlwaysFailingOrderSnapshots implements OrderSnapshotPort {
  int calls = 0;

  @override
  Future<void> clearOrderSnapshots() async {
    calls++;
    throw Exception('order wipe boom');
  }
}

void main() {
  test('the late order-wipe retry swallows its own failure', () async {
    final orders = _AlwaysFailingOrderSnapshots();
    final cubit = AuthCubit(
      authRepository: _StubAuthRepository(),
      profileRepository: _StubProfileRepository(),
      orderSnapshots: orders,
    );
    addTearDown(cubit.close);

    await cubit.clearLocalSnapshots();
    await pumpEventQueue();

    expect(orders.calls, 3,
        reason: 'first attempt, inline retry and the late retry all ran');
  });
}
