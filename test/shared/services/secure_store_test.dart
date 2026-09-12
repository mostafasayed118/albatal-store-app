import 'dart:convert';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/data/local_address_repository.dart';
import 'package:al_batal_elite/features/addresses/domain/address.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/shared/services/secure_store.dart';
import 'package:al_batal_elite/shared/services/supabase_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/memory_secure_store.dart';

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

const _addressJson = {
  'id': 'a1',
  'recipient': 'Ahmed Hassan',
  'line': '12 Nile Street',
  'city': 'Cairo',
  'country': 'EG',
  'isDefault': true,
};

Order _seedOrder() => Order(
      id: 'ord-1',
      items: const [],
      subtotal: const Money(1000),
      shipping: const Money(0),
      total: const Money(1000),
      status: OrderStatus.placed,
      placedAt: DateTime.parse('2026-09-01T00:00:00Z'),
      paymentMethod: 'cod',
    );

void main() {
  group('SecureStore hardening', () {
    test('uses hardware-backed options on both platforms', () {
      // iOS: accessible after first unlock, this device only (no
      // backup migration, no pre-unlock access).
      expect(
        FlutterSecureStore.iosOptions.toMap()['accessibility'],
        'first_unlock_this_device',
      );
      // Android: Keystore-backed AES-GCM (v11 default), reset on error.
      expect(
        FlutterSecureStore.androidOptions.toMap()['resetOnError'],
        'true',
      );
    });

    test('memory fake round-trips read/write/delete', () async {
      final store = MemorySecureStore();
      expect(await store.read('k'), isNull);
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
      await store.delete('k');
      expect(await store.read('k'), isNull);
    });
  });

  group('address book migration', () {
    test('migrates legacy cleartext prefs into the secure store once',
        () async {
      SharedPreferences.setMockInitialValues({
        'saved_addresses_v1': jsonEncode([_addressJson]),
      });
      final prefs = await SharedPreferences.getInstance();
      final secure = MemorySecureStore();
      final repo = LocalAddressRepository(prefs, secureStore: secure);

      final addresses = await repo.read() as Success<List<Address>>;

      expect(addresses.value, hasLength(1));
      expect(addresses.value.first.recipient, 'Ahmed Hassan');
      // Lifted into the encrypted store, legacy cleartext removed.
      expect(secure.values['saved_addresses_v1'], isNotNull);
      expect(prefs.getString('saved_addresses_v1'), isNull);
      // Second read serves from secure without touching prefs.
      final again = await repo.read() as Success<List<Address>>;
      expect(again.value, hasLength(1));
    });

    test('save writes to the secure store, never to cleartext prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secure = MemorySecureStore();
      final repo = LocalAddressRepository(prefs, secureStore: secure);

      final result = await repo.save(const [
        Address(
          id: 'a1',
          recipient: 'Ahmed Hassan',
          line: '12 Nile Street',
          city: 'Cairo',
          country: 'EG',
        ),
      ]);

      expect(result, isA<Success<void>>());
      expect(secure.values['saved_addresses_v1'], isNotNull);
      expect(prefs.getString('saved_addresses_v1'), isNull);
    });
  });

  group('order snapshot migration', () {
    test('migrates legacy cleartext orders into the secure store once',
        () async {
      SharedPreferences.setMockInitialValues({
        'storefront_orders_v1': jsonEncode([OrderCodec.encode(_seedOrder())]),
      });
      final prefs = await SharedPreferences.getInstance();
      final secure = MemorySecureStore();
      final persistence =
          LocalStorefrontPersistence(prefs, secureStore: secure);

      final orders = await persistence.readOrders();

      expect(orders, hasLength(1));
      expect(orders.first.id, 'ord-1');
      expect(secure.values['storefront_orders_v1'], isNotNull);
      expect(prefs.getString('storefront_orders_v1'), isNull);
    });

    test('cart and wishlist stay in plain prefs, not the secure store',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secure = MemorySecureStore();
      final persistence =
          LocalStorefrontPersistence(prefs, secureStore: secure);

      await persistence.writeCart(const []);
      await persistence.writeWishlist({'p1'});

      expect(prefs.getString('storefront_cart_lines_v1'), isNotNull);
      expect(prefs.getString('storefront_wishlist_ids_v1'), isNotNull);
      expect(secure.values, isEmpty);
    });
  });

  group('auth wipe covers the encrypted keys', () {
    Future<
        (
          AuthCubit,
          MemorySecureStore,
          LocalAddressRepository,
          LocalStorefrontPersistence
        )> seedWipedCubit() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final secure = MemorySecureStore({
        'saved_addresses_v1': jsonEncode([_addressJson]),
        'storefront_orders_v1': jsonEncode([OrderCodec.encode(_seedOrder())]),
      });
      final addressRepo = LocalAddressRepository(prefs, secureStore: secure);
      final persistence =
          LocalStorefrontPersistence(prefs, secureStore: secure);
      final cubit = AuthCubit(
        authRepository: _StubAuthRepository(),
        profileRepository: _StubProfileRepository(),
        addressRepository: addressRepo,
        orderSnapshots: persistence,
      );
      return (cubit, secure, addressRepo, persistence);
    }

    test('signOut deletes addresses and orders from the secure store',
        () async {
      final (cubit, secure, addressRepo, persistence) = await seedWipedCubit();

      await cubit.signOut();

      expect(secure.values, isEmpty);
      expect(
          (await addressRepo.read() as Success<List<Address>>).value, isEmpty);
      expect(await persistence.readOrders(), isEmpty);
      expect(cubit.state.status, AuthStatus.unauthenticated);
      await cubit.close();
    });

    test('deleteAccount success deletes addresses and orders', () async {
      final (cubit, secure, addressRepo, persistence) = await seedWipedCubit();

      final result = await cubit.deleteAccount(email: 'a@b.com');

      expect(result, isA<Success<void>>());
      expect(secure.values, isEmpty);
      expect(
          (await addressRepo.read() as Success<List<Address>>).value, isEmpty);
      expect(await persistence.readOrders(), isEmpty);
      await cubit.close();
    });
  });

  group('Supabase secure session storage', () {
    const sessionKey = 'sb-testref-auth-token';
    const sessionJson = '{"access_token":"tok","user":{}}';

    test('persists and restores the session without cleartext prefs', () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      final secure = MemorySecureStore();
      final storage = SecureSessionStorage(
        persistSessionKey: sessionKey,
        secureStore: secure,
      );

      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);

      await storage.persistSession(sessionJson);

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), sessionJson);
      expect(secure.values[sessionKey], sessionJson);

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('migrates a legacy cleartext session into the secure store', () async {
      SharedPreferences.setMockInitialValues({sessionKey: sessionJson});
      final prefs = await SharedPreferences.getInstance();
      final secure = MemorySecureStore();
      final storage = SecureSessionStorage(
        persistSessionKey: sessionKey,
        secureStore: secure,
      );

      await storage.initialize();

      expect(secure.values[sessionKey], sessionJson);
      expect(prefs.getString(sessionKey), isNull);
      expect(await storage.accessToken(), sessionJson);
    });

    test('broken keystore degrades to signed-out instead of throwing',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      final storage = SecureSessionStorage(
        persistSessionKey: sessionKey,
        secureStore: ThrowingSecureStore(),
      );

      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
      // Sign-out path must never throw into the auth flow.
      await storage.removePersistedSession();
    });

    test('PKCE verifier round-trips through the secure store', () async {
      final secure = MemorySecureStore();
      final storage = SecureGotrueStorage(secureStore: secure);

      await storage.setItem(key: 'code-verifier', value: 'verifier-123');
      expect(await storage.getItem(key: 'code-verifier'), 'verifier-123');
      expect(secure.values['code-verifier'], 'verifier-123');
      await storage.removeItem(key: 'code-verifier');
      expect(await storage.getItem(key: 'code-verifier'), isNull);
    });

    test('broken keystore degrades PKCE reads/removes instead of throwing',
        () async {
      final storage = SecureGotrueStorage(secureStore: ThrowingSecureStore());
      expect(await storage.getItem(key: 'code-verifier'), isNull);
      await storage.removeItem(key: 'code-verifier');
    });
  });
}
