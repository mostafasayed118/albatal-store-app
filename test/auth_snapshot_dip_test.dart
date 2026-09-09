import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/address.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
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
  Future<Result<void>> updatePassword(String password) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);

  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();
}

class _StubProfileRepository implements ProfileRepository {
  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);

  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      const Success(null);
}

/// Abstraction-first double: implements the domain ports only, proving
/// [AuthCubit] depends on abstractions rather than data-layer concretes.
class _FakeSnapshotPorts
    implements ClearableAddressRepository, OrderSnapshotPort {
  int addressClears = 0;
  int orderClears = 0;

  @override
  Future<Result<List<Address>>> read() async => const Success(<Address>[]);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);

  @override
  Future<Result<void>> clearAddresses() async {
    addressClears++;
    return const Success(null);
  }

  @override
  Future<void> clearOrderSnapshots() async {
    orderClears++;
  }
}

void main() {
  group('AuthCubit snapshot DIP', () {
    test('signOut clears snapshots through the domain ports', () async {
      final ports = _FakeSnapshotPorts();
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: _StubProfileRepository(),
        addressRepository: ports,
        orderSnapshots: ports,
      );

      await cubit.signOut();

      expect(ports.addressClears, 1);
      expect(ports.orderClears, 1);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      await cubit.close();
    });

    test('deleteAccount success clears snapshots through the domain ports',
        () async {
      final ports = _FakeSnapshotPorts();
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: _StubProfileRepository(),
        addressRepository: ports,
        orderSnapshots: ports,
      );

      final outcome = await cubit.deleteAccount(email: 'a@b.com');

      expect(outcome, isA<Success<void>>());
      expect(ports.addressClears, 1);
      expect(ports.orderClears, 1);
      await cubit.close();
    });

    test('plain AddressRepository without wipe capability is skipped safely',
        () async {
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: _StubProfileRepository(),
        addressRepository: _ReadOnlyAddressRepository(),
      );

      await cubit.signOut();

      expect(cubit.state.status, AuthStatus.unauthenticated);
      await cubit.close();
    });
  });
}

/// Address book double WITHOUT the wipe capability: the cubit must not
/// crash when the injected abstraction cannot clear.
class _ReadOnlyAddressRepository implements AddressRepository {
  @override
  Future<Result<List<Address>>> read() async => const Success(<Address>[]);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}
