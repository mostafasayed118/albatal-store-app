import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/idempotency_store.dart';
import 'package:al_batal_elite/features/storefront/domain/usecases/place_checkout_order_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/products_data.dart';

/// Hand-rolled stub matching the project's existing test style
/// (checkout_cubit_test.dart's MockCheckoutRepository).
class _StubCheckoutRepository implements CheckoutRepository {
  Result<PendingOrder>? result;
  Result<PendingOrder>? secondResult;
  int callCount = 0;
  final List<({Map<String, dynamic> addressSnapshot, String? idempotencyKey})>
      calls = [];

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    callCount++;
    calls.add((
      addressSnapshot: addressSnapshot,
      idempotencyKey: idempotencyKey,
    ));
    if (callCount > 1 && secondResult != null) return secondResult!;
    return result ?? const Failure(AppError('No result configured'));
  }
}

class _MemoryIdempotencyStore implements IdempotencyStore {
  String? key;
  int? timestampMs;
  int clearCount = 0;

  @override
  String? loadKey() => key;

  @override
  int? loadTimestampMs() => timestampMs;

  @override
  Future<void> saveKey(String key, int timestampMs) async {
    this.key = key;
    this.timestampMs = timestampMs;
  }

  @override
  Future<void> clear() async {
    key = null;
    timestampMs = null;
    clearCount++;
  }
}

const _testAddress = Address(
  id: 'addr-1',
  recipient: 'Test User',
  line: '123 Test St',
  city: 'Cairo',
  country: 'Egypt',
);

PendingOrder _pending(
        {String orderId = 'server-ord-001', String status = 'pending'}) =>
    PendingOrder(
      orderId: orderId,
      subtotal: const Money.egp(500),
      shipping: const Money.egp(50),
      total: const Money.egp(550),
      expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
      status: status,
    );

List<CartItem> _items() => [
      CartItem(
          product: products.first, color: 'Emerald', length: '2m', quantity: 2),
    ];

void main() {
  group('PlaceCheckoutOrderUseCase', () {
    late _StubCheckoutRepository repo;
    late _MemoryIdempotencyStore store;

    setUp(() {
      repo = _StubCheckoutRepository();
      store = _MemoryIdempotencyStore();
    });

    PlaceCheckoutOrderUseCase usecase({DateTime Function()? clock}) =>
        PlaceCheckoutOrderUseCase(
          checkoutRepository: repo,
          idempotencyStore: store,
          clock: clock,
        );

    test('generates a key, persists it, and builds the 5-key snapshot',
        () async {
      repo.result = Success(_pending());
      final outcome = await usecase().call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.pending!.orderId, 'server-ord-001');
      expect(outcome.idempotencyKey, isNotEmpty);
      // Persisted for crash-restart recovery.
      expect(store.key, outcome.idempotencyKey);
      expect(store.timestampMs, isNotNull);
      expect(repo.callCount, 1);
      expect(repo.calls.single.idempotencyKey, outcome.idempotencyKey);
      final snapshot = repo.calls.single.addressSnapshot;
      expect(snapshot, {
        'id': 'addr-1',
        'recipient': 'Test User',
        'line': '123 Test St',
        'city': 'Cairo',
        'country': 'Egypt',
      });
    });

    test('null address sends an empty snapshot', () async {
      repo.result = Success(_pending());
      final outcome = await usecase().call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
      );

      expect(outcome.isSuccess, isTrue);
      expect(repo.calls.single.addressSnapshot, isEmpty);
    });

    test('in-session key wins over the persisted key on retry', () async {
      repo.result = Success(_pending());
      await store.saveKey('persisted-old', 1000);

      final outcome = await usecase().call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
        inSessionKey: 'in-session-key',
      );

      expect(outcome.idempotencyKey, 'in-session-key');
      expect(repo.calls.single.idempotencyKey, 'in-session-key');
    });

    test('restores a fresh persisted key after an app restart', () async {
      repo.result = Success(_pending());
      final now = DateTime.parse('2026-02-01T00:00:00Z');
      await store.saveKey('restart-key', now.millisecondsSinceEpoch - 1000);

      final outcome = await usecase(clock: () => now).call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
      );

      expect(outcome.idempotencyKey, 'restart-key');
      expect(repo.calls.single.idempotencyKey, 'restart-key');
    });

    test('expired persisted key is discarded for a fresh one', () async {
      repo.result = Success(_pending());
      final now = DateTime.parse('2026-02-01T00:00:00Z');
      await store.saveKey(
        'stale-key',
        now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
      );

      final outcome = await usecase(clock: () => now).call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
      );

      expect(outcome.idempotencyKey, isNot('stale-key'));
      expect(repo.calls.single.idempotencyKey, outcome.idempotencyKey);
    });

    test('repository failure propagates without a retry, key still returned',
        () async {
      repo.result = const Failure(AppError('Insufficient stock'));

      final outcome = await usecase().call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
      );

      expect(outcome.isSuccess, isFalse);
      expect(outcome.error?.message, 'Insufficient stock');
      expect(outcome.pending, isNull);
      expect(repo.callCount, 1);
      // The key stays persisted AND is returned so the cubit keeps it in
      // state and the user can retry the same attempt.
      expect(outcome.idempotencyKey, isNotEmpty);
      expect(store.key, outcome.idempotencyKey);
    });

    test('non-pending resurrected order retries ONCE with a fresh key',
        () async {
      repo.result = Success(_pending(orderId: 'dead-ord', status: 'paid'));
      repo.secondResult = Success(_pending(orderId: 'fresh-ord'));

      final outcome = await usecase().call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
      );

      expect(repo.callCount, 2);
      final firstKey = repo.calls[0].idempotencyKey;
      final secondKey = repo.calls[1].idempotencyKey;
      expect(firstKey, isNotNull);
      expect(secondKey, isNotNull);
      expect(secondKey, isNot(firstKey));
      expect(store.key, secondKey);
      expect(outcome.pending!.orderId, 'fresh-ord');
      expect(outcome.idempotencyKey, secondKey);
    });

    test('double non-pending does not loop forever', () async {
      repo.result = Success(_pending(orderId: 'dead-1', status: 'paid'));
      repo.secondResult = Success(_pending(orderId: 'dead-2', status: 'paid'));

      final outcome = await usecase().call(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: _testAddress,
      );

      expect(repo.callCount, 2);
      expect(outcome.pending!.orderId, 'dead-2');
    });

    test('clearPersistedKey wipes the store', () async {
      await store.saveKey('k', 1);
      await usecase().clearPersistedKey();
      expect(store.key, isNull);
      expect(store.clearCount, 1);
    });
  });
}
