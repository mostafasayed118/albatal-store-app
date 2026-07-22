import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrdersCubit', () {
    blocTest<OrdersCubit, OrdersState>(
      'reconcile upserts by order id — same order twice yields one entry',
      build: () => OrdersCubit(MemoryStorefrontPersistence()),
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
        await cubit.reconcile(serverOrder);
      },
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(1));
        expect(cubit.state.orders.single.id, 'SERVER-001');
        expect(cubit.state.orders.single.status, OrderStatus.paid);
      },
    );

    test('orders survive a cubit recreation through the same store', () async {
      final store = MemoryStorefrontPersistence();
      final a = OrdersCubit(store);
      await a.reconcile(Order(
        id: 'ORD-PERSIST',
        items: [],
        subtotal: Money.zero,
        shipping: Money.zero,
        total: Money.egp(100),
        status: OrderStatus.paid,
        placedAt: DateTime(2026),
        paymentMethod: 'Digital Wallet',
      ));

      final b = OrdersCubit(store);
      await b.restore();

      expect(b.state.orders, hasLength(1));
      expect(b.state.orders.single.id, 'ORD-PERSIST');
      expect(b.state.orders.single.paymentMethod, 'Digital Wallet');
      await a.close();
      await b.close();
    });

    blocTest<OrdersCubit, OrdersState>(
      'reconcile appends a new order and preserves existing ones',
      build: () => OrdersCubit(MemoryStorefrontPersistence()),
      act: (cubit) async {
        await cubit.reconcile(Order(
          id: 'EXISTING-001',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(50),
          status: OrderStatus.paid,
          placedAt: DateTime(2026),
          paymentMethod: 'paymob_card',
        ));
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
        expect(ids, containsAll(['EXISTING-001', 'SERVER-002']));
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'reconcile updates status of existing order',
      build: () => OrdersCubit(MemoryStorefrontPersistence()),
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
        await cubit.reconcile(pending.copyWith(status: OrderStatus.paid));
      },
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(1));
        expect(cubit.state.orders.single.status, OrderStatus.paid);
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'advance does not modify order status — server-managed only',
      build: () => OrdersCubit(MemoryStorefrontPersistence()),
      act: (cubit) async {
        await cubit.reconcile(Order(
          id: 'ORD-ADVANCE',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(50),
          status: OrderStatus.placed,
          placedAt: DateTime(2026),
          paymentMethod: 'Cash on Delivery',
        ));
        await cubit.advance('ORD-ADVANCE');
      },
      verify: (cubit) {
        expect(cubit.state.orders, hasLength(1));
        expect(cubit.state.orders.single.status, OrderStatus.placed);
        expect(cubit.state.status, OrdersStatus.error);
        expect(cubit.state.errorMessage, contains('server-managed'));
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'paid orders appear in active list',
      build: () => OrdersCubit(MemoryStorefrontPersistence()),
      act: (cubit) async {
        await cubit.reconcile(Order(
          id: 'ORD-PAID',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(50),
          status: OrderStatus.paid,
          placedAt: DateTime(2026),
          paymentMethod: 'paymob_card',
        ));
      },
      verify: (cubit) {
        expect(cubit.state.active, hasLength(1));
        expect(cubit.state.completed, isEmpty);
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'delivered orders appear in completed list',
      build: () => OrdersCubit(MemoryStorefrontPersistence()),
      act: (cubit) async {
        await cubit.reconcile(Order(
          id: 'ORD-DELIVERED',
          items: [],
          subtotal: Money.zero,
          shipping: Money.zero,
          total: Money.egp(50),
          status: OrderStatus.delivered,
          placedAt: DateTime(2026),
          paymentMethod: 'paymob_card',
        ));
      },
      verify: (cubit) {
        expect(cubit.state.active, isEmpty);
        expect(cubit.state.completed, hasLength(1));
      },
    );
  });

  group('OrdersCubit persistence failure', () {
    test('reconcile surfaces error on write failure', () async {
      final failingStore = _FailingOrdersPersistence();
      final cubit = OrdersCubit(failingStore);

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

      expect(cubit.state.orders, hasLength(1));
      expect(cubit.state.status, OrdersStatus.error);
      await cubit.close();
    });
  });
}

class _FailingOrdersPersistence implements OrdersRepository {
  @override
  Future<Result<List<Order>>> readOrders() async => Success([]);

  @override
  Future<Result<void>> writeOrders(List<Order> orders) async =>
      Failure(AppError('write failed'));
}
