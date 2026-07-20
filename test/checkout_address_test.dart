import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub CheckoutRepository that returns a fake pending order.
class StubCheckoutRepository implements CheckoutRepository {
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    return Success(PendingOrder(
      orderId: 'ORD-STUB-1',
      subtotal: items.fold(Money.zero,
              (Money v, CartItem i) => v + (i.product.price * i.quantity)),
      shipping: Money.egp(75),
      total: items.fold(Money.zero,
              (Money v, CartItem i) => v + (i.product.price * i.quantity)) +
          Money.egp(75),
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    ));
  }
}

const testAddress = Address(
  id: 'addr-1',
  recipient: 'Ahmed Mansour',
  line: '12 El Tahrir Street',
  city: 'Cairo',
  country: 'Egypt',
  isDefault: true,
);

void main() {
  group('CheckoutCubit — address selection', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'selectAddress stores the chosen address',
      build: () => CheckoutCubit(StubCheckoutRepository()),
      act: (cubit) => cubit.selectAddress(testAddress),
      verify: (cubit) {
        expect(cubit.state.selectedAddress, testAddress);
        expect(cubit.state.hasAddress, isTrue);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'clearAddress removes the selected address',
      build: () => CheckoutCubit(StubCheckoutRepository()),
      act: (cubit) {
        cubit.selectAddress(testAddress);
        cubit.clearAddress();
      },
      verify: (cubit) {
        expect(cubit.state.selectedAddress, isNull);
        expect(cubit.state.hasAddress, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'selectAddress replaces previously selected address',
      build: () => CheckoutCubit(StubCheckoutRepository()),
      act: (cubit) {
        cubit.selectAddress(testAddress);
        cubit.selectAddress(const Address(
          id: 'addr-2',
          recipient: 'Fatima Hassan',
          line: '45 Nile Corniche',
          city: 'Alexandria',
          country: 'Egypt',
        ));
      },
      verify: (cubit) {
        expect(cubit.state.selectedAddress!.recipient, 'Fatima Hassan');
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'payment changes payment method',
      build: () => CheckoutCubit(StubCheckoutRepository()),
      act: (cubit) => cubit.payment('Cash on Delivery'),
      verify: (cubit) => expect(cubit.state.payment, 'Cash on Delivery'),
    );
  });

  group('OrdersCubit — address snapshot in order', () {
    test('place() stores the selected address on the order', () {
      final cubit = OrdersCubit(
        MemoryStorefrontPersistence(),
        generateId: () => 'ORD-ADDR-1',
      );
      final cart = CartState([
        CartItem(
            product: products.first,
            color: 'Emerald',
            length: '2m',
            quantity: 1),
      ]);

      final order = cubit.place(
        cart,
        paymentMethod: 'Credit Card',
        address: testAddress,
      );

      expect(order.address, testAddress);
      expect(order.address!.recipient, 'Ahmed Mansour');
      expect(order.address!.line, '12 El Tahrir Street');
    });

    test('place() works without an address (null)', () {
      final cubit = OrdersCubit(
        MemoryStorefrontPersistence(),
        generateId: () => 'ORD-ADDR-2',
      );
      final cart = CartState([
        CartItem(
            product: products.first,
            color: 'Emerald',
            length: '2m',
            quantity: 1),
      ]);

      final order = cubit.place(
        cart,
        paymentMethod: 'Cash on Delivery',
      );

      expect(order.address, isNull);
    });

    test('address persists through restore', () async {
      final store = MemoryStorefrontPersistence();
      final a = OrdersCubit(store, generateId: () => 'ORD-PERSIST');
      a.place(
        CartState([
          CartItem(product: products.first, color: 'Emerald', length: '2m')
        ]),
        paymentMethod: 'Credit Card',
        address: testAddress,
      );

      final b = OrdersCubit(store, generateId: () => 'SHOULD-NOT');
      await b.restore();

      expect(b.state.orders.single.address, testAddress);
      expect(b.state.orders.single.address!.recipient, 'Ahmed Mansour');
      await a.close();
      await b.close();
    });
  });
}
