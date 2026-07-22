import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('reconcile stores the selected address on the order', () async {
      final cubit = OrdersCubit(MemoryStorefrontPersistence());
      final orderWithAddress = Order(
        id: 'ORD-ADDR-1',
        items: [],
        subtotal: Money.zero,
        shipping: Money.zero,
        total: Money.zero,
        status: OrderStatus.paid,
        placedAt: DateTime.now(),
        paymentMethod: 'Credit Card',
        address: testAddress,
      );
      await cubit.reconcile(orderWithAddress);

      expect(cubit.state.orders.single.address, testAddress);
      expect(cubit.state.orders.single.address!.recipient, 'Ahmed Mansour');
      expect(cubit.state.orders.single.address!.line, '12 El Tahrir Street');
      await cubit.close();
    });

    test('reconcile works without an address (null)', () async {
      final cubit = OrdersCubit(MemoryStorefrontPersistence());
      final orderNoAddress = Order(
        id: 'ORD-ADDR-2',
        items: [],
        subtotal: Money.zero,
        shipping: Money.zero,
        total: Money.zero,
        status: OrderStatus.paid,
        placedAt: DateTime.now(),
        paymentMethod: 'Cash on Delivery',
      );
      await cubit.reconcile(orderNoAddress);

      expect(cubit.state.orders.single.address, isNull);
      await cubit.close();
    });

    test('address persists through restore', () async {
      final store = MemoryStorefrontPersistence();
      final a = OrdersCubit(store);
      await a.reconcile(Order(
        id: 'ORD-PERSIST',
        items: [],
        subtotal: Money.zero,
        shipping: Money.zero,
        total: Money.zero,
        status: OrderStatus.paid,
        placedAt: DateTime.now(),
        paymentMethod: 'Credit Card',
        address: testAddress,
      ));

      final b = OrdersCubit(store);
      await b.restore();

      expect(b.state.orders.single.address, testAddress);
      expect(b.state.orders.single.address!.recipient, 'Ahmed Mansour');
      await a.close();
      await b.close();
    });
  });
}
