import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configurable stub for [CheckoutRepository] that records every
/// call and lets the test control the result, the number of calls,
/// and whether the result is a success or failure.
class MockCheckoutRepository implements CheckoutRepository {
  MockCheckoutRepository({this.result});

  Result<PendingOrder>? result;
  int callCount = 0;
  List<
      ({
        List<CartItem> items,
        String paymentMethod,
        Map<String, dynamic> address,
        String? idempotencyKey
      })> calls = [];

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    callCount++;
    calls.add((
      items: items,
      paymentMethod: paymentMethod,
      address: addressSnapshot,
      idempotencyKey: idempotencyKey,
    ));
    return result ?? Failure(const AppError('No result configured'));
  }
}

const _testAddress = Address(
  id: 'addr-1',
  recipient: 'Test User',
  line: '123 Test St',
  city: 'Cairo',
  country: 'Egypt',
);

final _serverPendingOrder = PendingOrder(
  orderId: 'server-ord-001',
  subtotal: Money.egp(500),
  shipping: Money.egp(50),
  total: Money.egp(550),
  expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
);

void main() {
  group('CheckoutCubit', () {
    late MockCheckoutRepository repo;
    late CheckoutCubit cubit;

    setUp(() {
      repo = MockCheckoutRepository();
      cubit = CheckoutCubit(repo);
    });

    tearDown(() => cubit.close());

    test('initial state is initial with default payment', () {
      expect(cubit.state.status, CheckoutStatus.initial);
      expect(cubit.state.payment, 'Credit Card');
      expect(cubit.state.selectedAddress, isNull);
      expect(cubit.state.idempotencyKey, isNull);
    });

    test('selectAddress stores the address', () {
      cubit.selectAddress(_testAddress);
      expect(cubit.state.selectedAddress, _testAddress);
      expect(cubit.state.hasAddress, isTrue);
    });

    test('payment updates the payment method', () {
      cubit.payment('Cash on Delivery');
      expect(cubit.state.payment, 'Cash on Delivery');
    });

    // ─── Test 1: Successful order creation ──────────────────

    test('successful order creation transitions to placing with server totals',
        () async {
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );

      expect(cubit.state.status, CheckoutStatus.placing);
      expect(cubit.state.pendingOrderId, 'server-ord-001');
      expect(cubit.state.serverSubtotal, Money.egp(500));
      expect(cubit.state.serverShipping, Money.egp(50));
      expect(cubit.state.serverTotal, Money.egp(550));
      expect(cubit.state.idempotencyKey, isNotNull);
    });

    // ─── Test 2: Insufficient stock error ───────────────────

    test('insufficient stock error transitions to error with message',
        () async {
      repo.result = Failure(const AppError(
        'Insufficient stock for Royal Emerald Silk (2m/Emerald). Available: 1',
      ));
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 5),
        ],
      );

      expect(cubit.state.status, CheckoutStatus.error);
      expect(cubit.state.errorMessage, contains('Insufficient stock'));
      expect(cubit.state.pendingOrderId, isNull);
    });

    // ─── Test 3: Retry with same idempotency key ──────────────

    test('retry with same idempotency key reuses the key', () async {
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      final items = [
        CartItem(
            product: products.first,
            color: 'Emerald',
            length: '2m',
            quantity: 2),
      ];

      // First call — generates the key
      await cubit.createPendingOrder(cartItems: items);
      final firstKey = cubit.state.idempotencyKey;
      expect(firstKey, isNotNull);
      expect(repo.callCount, 1);
      expect(repo.calls.first.idempotencyKey, firstKey);

      // Simulate a network failure → user retries
      cubit.markError('Network error');
      expect(cubit.state.status, CheckoutStatus.error);

      // Retry — must reuse the SAME key
      await cubit.createPendingOrder(cartItems: items);
      expect(cubit.state.idempotencyKey, firstKey);
      expect(repo.callCount, 2);
      expect(repo.calls.last.idempotencyKey, firstKey);
    });

    test('idempotent retry returns the existing order from server', () async {
      // First call succeeds
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );
      expect(cubit.state.status, CheckoutStatus.placing);
      expect(cubit.state.pendingOrderId, 'server-ord-001');

      // Second call with the same key — server returns the same order
      // with isIdempotentRetry=true. The cubit should still transition
      // to placing with the same order.
      repo.result = Success(PendingOrder(
        orderId: 'server-ord-001',
        subtotal: Money.egp(500),
        shipping: Money.egp(50),
        total: Money.egp(550),
        expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
        isIdempotentRetry: true,
      ));

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );
      expect(cubit.state.status, CheckoutStatus.placing);
      expect(cubit.state.pendingOrderId, 'server-ord-001');
    });

    // ─── Test 4: Rollback / no partial data on failure ────────

    test('failure does not set pending order or server totals', () async {
      repo.result = Failure(const AppError('Stock race: insufficient stock'));
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );

      expect(cubit.state.status, CheckoutStatus.error);
      expect(cubit.state.pendingOrderId, isNull);
      expect(cubit.state.serverTotal, isNull);
      expect(cubit.state.serverSubtotal, isNull);
      expect(cubit.state.serverShipping, isNull);
    });

    // ─── Test 5: Server price differs from client ─────────────

    test('server price differs from client — cubit uses server totals',
        () async {
      // The client thinks the product costs 1000 EGP (products.first.price)
      // but the server returns 500 EGP subtotal (different from client).
      // The cubit must use the server's totals, not the client's.
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );

      // The cubit stores the SERVER total, not the client-computed total.
      final clientTotal = cubit.state.serverTotal;
      expect(clientTotal, Money.egp(550));
      // The client cart would have computed a different total based on
      // the local product price. The server's total is authoritative.
      expect(clientTotal, isNot(products.first.price * 2));
    });

    // ─── Test 6: Server shipping differs from client ──────────

    test('server shipping differs from client — cubit uses server shipping',
        () async {
      // The client cart computes shipping as Money.egp(75) (hardcoded
      // in CartState.shipping). The server may compute a different
      // shipping fee based on the address's governorate.
      repo.result = Success(PendingOrder(
        orderId: 'server-ord-002',
        subtotal: Money.egp(1000),
        shipping: Money.egp(30), // Different from client's 75
        total: Money.egp(1030),
        expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
      ));
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );

      // The cubit uses the server's shipping, not the client's.
      expect(cubit.state.serverShipping, Money.egp(30));
      expect(cubit.state.serverTotal, Money.egp(1030));
    });

    // ─── Test 7: Unauthorized caller rejection ───────────────

    test('unauthorized caller rejection transitions to error', () async {
      repo.result = Failure(const AppError('Authentication required'));
      // Don't select an address — the server will reject before
      // even validating the address because auth fails.

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ],
      );

      expect(cubit.state.status, CheckoutStatus.error);
      expect(cubit.state.errorMessage, 'Authentication required');
      expect(cubit.state.pendingOrderId, isNull);
    });

    // ─── Additional: idempotency key uniqueness ───────────────

    test('different checkout attempts get different idempotency keys',
        () async {
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      final items = [
        CartItem(
            product: products.first,
            color: 'Emerald',
            length: '2m',
            quantity: 2),
      ];

      // First checkout attempt
      await cubit.createPendingOrder(cartItems: items);
      final firstKey = cubit.state.idempotencyKey;

      // Reset for a new checkout attempt
      cubit.resetForNewAttempt();
      expect(cubit.state.idempotencyKey, isNull);

      // Second checkout attempt — new key
      await cubit.createPendingOrder(cartItems: items);
      final secondKey = cubit.state.idempotencyKey;

      expect(firstKey, isNot(secondKey));
    });

    test('address snapshot includes all required fields', () async {
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 1),
        ],
      );

      expect(repo.callCount, 1);
      final call = repo.calls.first;
      expect(call.address['recipient'], 'Test User');
      expect(call.address['line'], '123 Test St');
      expect(call.address['city'], 'Cairo');
      expect(call.address['country'], 'Egypt');
      expect(call.address['id'], 'addr-1');
    });

    test('items are mapped to product_id, size, color, quantity', () async {
      repo.result = Success(_serverPendingOrder);
      cubit.selectAddress(_testAddress);

      await cubit.createPendingOrder(
        cartItems: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 3),
        ],
      );

      expect(repo.callCount, 1);
      final call = repo.calls.first;
      expect(call.items.length, 1);
      // The CartItem.product.id is used, not any client price
      expect(call.items.first.product.id, products.first.id);
      expect(call.items.first.color, 'Emerald');
      expect(call.items.first.length, '2m');
      expect(call.items.first.quantity, 3);
    });
  });
}
