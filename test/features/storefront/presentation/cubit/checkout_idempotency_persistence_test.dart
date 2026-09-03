import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubCheckoutRepo implements CheckoutRepository {
  _StubCheckoutRepo();
  final List<String?> keys = [];

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    return const Failure(AppError('transient network error'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutCubit — idempotency key persistence (24h TTL)', () {
    test('persists key to SharedPreferences after createPendingOrder',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = CheckoutCubit(_StubCheckoutRepo(), prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubit.createPendingOrder(cartItems: items);

      expect(prefs.getString('checkout_idempotency_key'),
          cubit.state.idempotencyKey);
      expect(prefs.getInt('checkout_idempotency_key_ts'), isNotNull);

      await cubit.close();
    });

    test('new cubit restores persisted key within TTL (app restart)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repoA = _StubCheckoutRepo();
      final cubitA = CheckoutCubit(repoA, prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubitA.createPendingOrder(cartItems: items);
      final firstKey = cubitA.state.idempotencyKey;
      await cubitA.close();

      // Simulate app restart: new cubit sharing the same SharedPreferences
      final repoB = _StubCheckoutRepo();
      final cubitB = CheckoutCubit(repoB, prefs: prefs);
      await cubitB.createPendingOrder(cartItems: items);

      expect(repoB.keys.first, firstKey,
          reason: 'restored key must be reused after app restart');

      await cubitB.close();
    });

    test('persisted key older than 24h TTL is ignored', () async {
      final staleTs = DateTime.now().millisecondsSinceEpoch -
          const Duration(hours: 25).inMilliseconds;
      SharedPreferences.setMockInitialValues({
        'checkout_idempotency_key': 'cko-stale-key',
        'checkout_idempotency_key_ts': staleTs,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = _StubCheckoutRepo();
      final cubit = CheckoutCubit(repo, prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubit.createPendingOrder(cartItems: items);

      expect(repo.keys.first, isNot(equals('cko-stale-key')));
      expect(repo.keys.first, startsWith('cko-'));

      await cubit.close();
    });

    test('resetForNewAttempt clears the persisted key', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = CheckoutCubit(_StubCheckoutRepo(), prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubit.createPendingOrder(cartItems: items);
      expect(prefs.getString('checkout_idempotency_key'), isNotNull);

      cubit.resetForNewAttempt();

      expect(prefs.getString('checkout_idempotency_key'), isNull);
      expect(prefs.getInt('checkout_idempotency_key_ts'), isNull);

      await cubit.close();
    });

    test('markSuccess clears the persisted key', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = CheckoutCubit(_StubCheckoutRepo(), prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubit.createPendingOrder(cartItems: items);
      expect(prefs.getString('checkout_idempotency_key'), isNotNull);

      cubit.markSuccess();

      expect(prefs.getString('checkout_idempotency_key'), isNull);

      await cubit.close();
    });
  });

  group('dead-order recovery (restored key hits cancelled order)', () {
    test('discards the dead key and retries once with a fresh key',
        () async {
      SharedPreferences.setMockInitialValues({
        'checkout_idempotency_key': 'cko-stale-dead-key',
        'checkout_idempotency_key_ts':
            DateTime.now().millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = _SequencedCheckoutRepo();
      final cubit = CheckoutCubit(repo, prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubit.createPendingOrder(cartItems: items);

      // First call reused the restored dead key, second used a fresh key.
      expect(repo.keys, hasLength(2));
      expect(repo.keys.first, 'cko-stale-dead-key');
      expect(repo.keys.last, isNot(equals('cko-stale-dead-key')));
      // Final state carries the live pending order + the fresh key.
      expect(cubit.state.status, CheckoutStatus.placing);
      expect(cubit.state.pendingOrderId, 'ord-fresh');
      expect(cubit.state.idempotencyKey, repo.keys.last);
      expect(prefs.getString('checkout_idempotency_key'), repo.keys.last);

      await cubit.close();
    });

    test('no retry loop when the fresh order is also non-pending',
        () async {
      SharedPreferences.setMockInitialValues({
        'checkout_idempotency_key': 'cko-stale-dead-key',
        'checkout_idempotency_key_ts':
            DateTime.now().millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = _AlwaysDeadCheckoutRepo();
      final cubit = CheckoutCubit(repo, prefs: prefs);
      final items = [
        CartItem(product: products.first, color: 'Emerald', length: '2m'),
      ];

      await cubit.createPendingOrder(cartItems: items);

      // Exactly two attempts: restored key + one fresh retry, then stop.
      expect(repo.keys, hasLength(2));

      await cubit.close();
    });
  });
}

/// Returns a cancelled order for the stale key, then a live pending
/// order for any fresh key.
class _SequencedCheckoutRepo implements CheckoutRepository {
  final List<String?> keys = [];

  PendingOrder _order(String id, String status) => PendingOrder(
        orderId: id,
        subtotal: Money.egp(100),
        shipping: Money.zero,
        total: Money.egp(100),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        status: status,
      );

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (idempotencyKey == 'cko-stale-dead-key') {
      return Success(_order('ord-dead', 'cancelled'));
    }
    return Success(_order('ord-fresh', 'pending'));
  }
}

/// Always returns a cancelled order, whatever the key.
class _AlwaysDeadCheckoutRepo implements CheckoutRepository {
  final List<String?> keys = [];

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    return Success(PendingOrder(
      orderId: 'ord-dead',
      subtotal: Money.zero,
      shipping: Money.zero,
      total: Money.zero,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      status: 'cancelled',
    ));
  }
}
