import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/entities/address.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/order_snapshot_port.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _WipeStubAuthRepository implements AuthRepository {
  @override
  Future<Result<void>> completeOAuthCallback(Uri uri) async =>
      const Success(null);

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

class _WipeStubProfileRepository implements ProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      const Success(null);

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

/// Address double that returns a scripted sequence of results and keeps
/// counting after the script runs out (a failure stays a failure).
class _ScriptedClearableAddressRepository
    implements ClearableAddressRepository {
  _ScriptedClearableAddressRepository(this._results);

  final List<Result<void>> _results;
  int calls = 0;

  @override
  Future<Result<void>> clearAddresses() async {
    final index = calls < _results.length ? calls : _results.length - 1;
    calls++;
    return _results[index];
  }

  @override
  Future<Result<List<Address>>> read() async => const Success(<Address>[]);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

/// Order-snapshot double that throws for the first [failures] calls.
class _FlakyOrderSnapshots implements OrderSnapshotPort {
  _FlakyOrderSnapshots({required this.failures});

  final int failures;
  int calls = 0;

  @override
  Future<void> clearOrderSnapshots() async {
    calls++;
    if (calls <= failures) throw Exception('order wipe boom');
  }
}

AuthCubit _cubit({
  AddressRepository? addressRepository,
  OrderSnapshotPort? orderSnapshots,
}) =>
    AuthCubit(
      authRepository: _WipeStubAuthRepository(),
      profileRepository: _WipeStubProfileRepository(),
      addressRepository: addressRepository,
      orderSnapshots: orderSnapshots,
    );

void main() {
  const failure = Failure(AppError('clear failed'));

  group('AuthSnapshotWipe', () {
    test('retries a failed address clear once and stops when it succeeds',
        () async {
      final addresses =
          _ScriptedClearableAddressRepository(const [failure, Success(null)]);
      final cubit = _cubit(addressRepository: addresses);
      addTearDown(cubit.close);

      await cubit.clearLocalSnapshots();

      expect(addresses.calls, 2);
    });

    test('schedules a late retry when the address clear keeps failing',
        () async {
      final addresses = _ScriptedClearableAddressRepository(
          const [failure, failure, failure]);
      final cubit = _cubit(addressRepository: addresses);
      addTearDown(cubit.close);

      await cubit.clearLocalSnapshots();
      await pumpEventQueue();

      expect(addresses.calls, 3);
    });

    test('retries a throwing order wipe once and stops when it succeeds',
        () async {
      final orders = _FlakyOrderSnapshots(failures: 1);
      final cubit = _cubit(orderSnapshots: orders);
      addTearDown(cubit.close);

      await cubit.clearLocalSnapshots();

      expect(orders.calls, 2);
    });

    test('schedules a late retry when the order wipe keeps throwing', () async {
      final orders = _FlakyOrderSnapshots(failures: 2);
      final cubit = _cubit(orderSnapshots: orders);
      addTearDown(cubit.close);

      await cubit.clearLocalSnapshots();
      await pumpEventQueue();

      expect(orders.calls, 3);
    });
  });
}
