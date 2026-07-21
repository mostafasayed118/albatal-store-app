import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrdersCubit', () {
    blocTest<OrdersCubit, OrdersState>(
      'places an order that snapshots the cart and prepends to the list',
      build: () => OrdersCubit(MemoryStorefrontPersistence(),
          generateId: () => 'ORD-TEST-1'),
      act: (cubit) => cubit.place(
        CartState([
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 2),
        ]),
        paymentMethod: 'Credit Card',
      ),
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(1));
        final order = cubit.state.orders.single;
        expect(order.id, 'ORD-TEST-1');
        expect(order.status, OrderStatus.placed);
        expect(order.paymentMethod, 'Credit Card');
        expect(order.subtotal, products.first.price * 2);
        expect(order.itemCount, 2);
        expect(cubit.state.active, hasLength(1));
        expect(cubit.state.completed, isEmpty);
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'advances an active order placed -> shipped -> delivered',
      build: () => OrdersCubit(MemoryStorefrontPersistence(),
          generateId: () => 'ORD-TEST-2'),
      act: (cubit) async {
        await cubit.place(
          CartState([
            CartItem(product: products.first, color: 'Emerald', length: '2m')
          ]),
          paymentMethod: 'Cash on Delivery',
        );
        await cubit.advance('ORD-TEST-2');
        await cubit.advance('ORD-TEST-2');
      },
      expect: () => [
        isA<OrdersState>().having((s) => s.active, 'active', hasLength(1)),
        isA<OrdersState>(),
        isA<OrdersState>(),
      ],
      verify: (cubit) {
        final order = cubit.state.orders.single;
        expect(order.status, OrderStatus.delivered);
        expect(cubit.state.active, isEmpty);
        expect(cubit.state.completed, hasLength(1));
      },
    );

    test('orders survive a cubit recreation through the same store', () async {
      final store = MemoryStorefrontPersistence();
      final a = OrdersCubit(store, generateId: () => 'ORD-PERSIST');
      await a.place(
        CartState([
          CartItem(
              product: products.last, color: 'Ivory', length: '5m', quantity: 3)
        ]),
        paymentMethod: 'Digital Wallet',
      );

      final b = OrdersCubit(store, generateId: () => 'SHOULD-NOT-COLLIDE');
      await b.restore();

      expect(b.state.orders, hasLength(1));
      expect(b.state.orders.single.id, 'ORD-PERSIST');
      expect(b.state.orders.single.paymentMethod, 'Digital Wallet');
      expect(b.state.orders.single.itemCount, 3);
      await a.close();
      await b.close();
    });

    blocTest<OrdersCubit, OrdersState>(
      'reconcile upserts by order id — same order twice yields one entry',
      build: () => OrdersCubit(MemoryStorefrontPersistence(),
          generateId: () => 'ORD-RECONCILE'),
      act: (cubit) async {
        final serverOrder = Order(
          id: 'SERVER-001',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(50),
          status: OrderStatus.paid,
          placedAt: DateTime(2026),
          paymentMethod: 'paymob_card',
        );
        await cubit.reconcile(serverOrder);
        // Reconcile the same order again — should not duplicate.
        await cubit.reconcile(serverOrder);
      },
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(1));
        expect(cubit.state.orders.single.id, 'SERVER-001');
        expect(cubit.state.orders.single.status, OrderStatus.paid);
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'reconcile appends a new order and preserves existing ones',
      build: () => OrdersCubit(MemoryStorefrontPersistence(),
          generateId: () => 'ORD-APPEND'),
      act: (cubit) async {
        // Place a local order first.
        await cubit.place(
          CartState([
            CartItem(
                product: products.first,
                color: 'Emerald',
                length: '2m',
                quantity: 1),
          ]),
          paymentMethod: 'Cash on Delivery',
        );
        // Reconcile a different server order.
        await cubit.reconcile(Order(
          id: 'SERVER-002',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(100),
          status: OrderStatus.paid,
          placedAt: DateTime(2026),
          paymentMethod: 'paymob_card',
        ));
      },
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(2));
        final ids = cubit.state.orders.map((o) => o.id).toSet();
        expect(ids, containsAll(['ORD-APPEND', 'SERVER-002']));
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'reconcile updates status of existing order',
      build: () => OrdersCubit(MemoryStorefrontPersistence(),
          generateId: () => 'ORD-UPDATE'),
      act: (cubit) async {
        final pending = Order(
          id: 'SERVER-003',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(75),
          status: OrderStatus.pending,
          placedAt: DateTime(2026),
          paymentMethod: 'paymob_card',
        );
        await cubit.reconcile(pending);
        // Server confirms payment — reconcile with updated status.
        await cubit.reconcile(pending.copyWith(status: OrderStatus.paid));
      },
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(1));
        expect(cubit.state.orders.single.status, OrderStatus.paid);
      },
    );
  });

  group('OrdersCubit persistence failure', () {
    test('place surfaces error on write failure', () async {
      final failingStore = _FailingOrdersPersistence();
      final cubit = OrdersCubit(failingStore, generateId: () => 'ORD-FAIL');

      await cubit.place(
        CartState([
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 1),
        ]),
        paymentMethod: 'Credit Card',
      );

      // Order is in memory but persistence failed.
      expect(cubit.state.orders, hasLength(1));
      expect(cubit.state.status, OrdersStatus.error);
      expect(cubit.state.errorMessage, contains('write failed'));
      await cubit.close();
    });

    test('reconcile surfaces error on write failure', () async {
      final failingStore = _FailingOrdersPersistence();
      final cubit = OrdersCubit(failingStore, generateId: () => 'ORD-FAIL2');

      await cubit.reconcile(Order(
        id: 'SERVER-FAIL',
        items: [],
        subtotal: Money.zero,
        shipping: Money.zero,
        total: Money.egp(50),
        status: OrderStatus.paid,
        placedAt: DateTime(2026),
        paymentMethod: 'paymob_card',
      ));

      // Order is in memory but persistence failed.
      expect(cubit.state.orders, hasLength(1));
      expect(cubit.state.status, OrdersStatus.error);
      await cubit.close();
    });
  });
}

/// Test double that always fails on writeOrders.
class _FailingOrdersPersistence implements OrdersRepository {
  @override
  Future<Result<List<Order>>> readOrders() async => Success([]);

  @override
  Future<Result<void>> writeOrders(List<Order> orders) async =>
      Failure(AppError('write failed'));
}
