import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'helpers/memory_storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart'
    show OrderCodec;
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'fixtures/products_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrdersCubit', () {
    test('restore loads persisted orders into state', () async {
      final store = MemoryStorefrontPersistence();
      store.orderRecords = [
        OrderCodec.encode(Order(
          id: 'ORD-RESTORE-1',
          items: [
            CartItem(
                product: products.first,
                color: 'Emerald',
                length: '2m',
                quantity: 2),
          ],
          subtotal: products.first.price * 2,
          shipping: Money.zero,
          total: products.first.price * 2,
          status: OrderStatus.placed,
          placedAt: DateTime.utc(2026, 1, 1),
          paymentMethod: 'Credit Card',
        )),
      ];
      final cubit = OrdersCubit(store);
      await cubit.restore();

      expect(cubit.state.orders, hasLength(1));
      final order = cubit.state.orders.single;
      expect(order.id, 'ORD-RESTORE-1');
      expect(order.status, OrderStatus.placed);
      expect(order.paymentMethod, 'Credit Card');
      expect(order.subtotal, products.first.price * 2);
      expect(order.itemCount, 2);
      expect(cubit.state.active, hasLength(1));
      expect(cubit.state.completed, isEmpty);
      await cubit.close();
    });

    test('orders survive a cubit recreation through the same store', () async {
      final store = MemoryStorefrontPersistence();
      store.orderRecords = [
        OrderCodec.encode(Order(
          id: 'ORD-PERSIST',
          items: [
            CartItem(
                product: products.last,
                color: 'Ivory',
                length: '5m',
                quantity: 3),
          ],
          subtotal: products.last.price * 3,
          shipping: Money.zero,
          total: products.last.price * 3,
          status: OrderStatus.placed,
          placedAt: DateTime.utc(2026, 1, 1),
          paymentMethod: 'Digital Wallet',
        )),
      ];

      final b = OrdersCubit(store);
      await b.restore();

      expect(b.state.orders, hasLength(1));
      expect(b.state.orders.single.id, 'ORD-PERSIST');
      expect(b.state.orders.single.paymentMethod, 'Digital Wallet');
      expect(b.state.orders.single.itemCount, 3);
      await b.close();
    });

    test('restore surfaces error on read failure', () async {
      final cubit = OrdersCubit(_FailingOrdersRepository());

      await cubit.restore();

      // No orders loaded and the failure is surfaced, never thrown.
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.status, OrdersStatus.error);
      expect(cubit.state.errorMessage, contains('read failed'));
      await cubit.close();
    });
  });
  _tabMappingTests();
}

/// Test double that always fails on readOrders.
class _FailingOrdersRepository implements OrdersRepository {
  @override
  Future<Result<List<Order>>> readOrders() async =>
      Failure(AppError('read failed'));
}

Order _orderWithStatus(String id, OrderStatus status) => Order(
      id: id,
      items: const [],
      subtotal: Money.zero,
      shipping: Money.zero,
      total: Money.zero,
      status: status,
      placedAt: DateTime.utc(2026, 1, 1),
      paymentMethod: 'cod',
    );

void _tabMappingTests() {
  group('OrdersState tab mapping (live-found 2026-09-03)', () {
    test('paid orders land in completed (were invisible)', () {
      final state = OrdersState();
      final s =
          state.copyWith(orders: [_orderWithStatus('p1', OrderStatus.paid)]);
      expect(s.completed.map((o) => o.id), ['p1']);
      expect(s.active, isEmpty);
      expect(s.cancelled, isEmpty);
    });

    test('expired and refunded land in cancelled (were invisible)', () {
      final state = OrdersState();
      final s = state.copyWith(orders: [
        _orderWithStatus('e1', OrderStatus.expired),
        _orderWithStatus('r1', OrderStatus.refunded),
      ]);
      expect(s.cancelled.map((o) => o.id), containsAll(['e1', 'r1']));
      expect(s.active, isEmpty);
      expect(s.completed, isEmpty);
    });

    test('every OrderStatus is visible in exactly one tab', () {
      final state = OrdersState();
      for (final status in OrderStatus.values) {
        final s = state.copyWith(orders: [_orderWithStatus('x', status)]);
        final hits = [
          s.active.any((o) => o.id == 'x'),
          s.completed.any((o) => o.id == 'x'),
          s.cancelled.any((o) => o.id == 'x'),
        ].where((h) => h).length;
        expect(hits, 1, reason: '$status must appear in exactly one tab');
      }
    });
  });
}
