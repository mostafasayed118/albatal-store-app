import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrdersCubit', () {
    blocTest<OrdersCubit, OrdersState>(
      'places an order that snapshots the cart and prepends to the list',
      build: () =>
          OrdersCubit(MemoryStorefrontPersistence(), generateId: () => 'ORD-TEST-1'),
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
      build: () =>
          OrdersCubit(MemoryStorefrontPersistence(), generateId: () => 'ORD-TEST-2'),
      act: (cubit) {
        cubit.place(
          CartState([CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m')]),
          paymentMethod: 'Cash on Delivery',
        );
        cubit.advance('ORD-TEST-2');
        cubit.advance('ORD-TEST-2');
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
      a.place(
        CartState([CartItem(
            product: products.last,
            color: 'Ivory',
            length: '5m',
            quantity: 3)]),
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
  });
}
