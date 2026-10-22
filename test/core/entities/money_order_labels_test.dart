import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money labels', () {
    test('wholeEgpLabel trims trailing .00 and keeps fractions', () {
      expect(Money.wholeEgpLabel(1290), '1290');
      expect(Money.wholeEgpLabel(12.5), '12.50');
    });

    test('label renders whole and fractional minor units', () {
      expect(const Money(129000).label(), '1290');
      expect(const Money(99875).label(), '998.75');
    });

    test('wholeEgpLabelFromMinor delegates to label', () {
      expect(Money.wholeEgpLabelFromMinor(129000), '1290');
      expect(Money.wholeEgpLabelFromMinor(99875), '998.75');
    });
  });

  group('Order copyWith', () {
    final placedAt = DateTime.utc(2026, 1, 2);
    final address = const Address(
      id: 'a-1',
      recipient: 'Nour',
      line: '1 Nile St',
      city: 'Cairo',
      country: 'EG',
    );
    final order = Order(
      id: 'ORD-1',
      items: const [],
      subtotal: const Money(10000),
      shipping: Money.zero,
      total: const Money(10000),
      status: OrderStatus.placed,
      placedAt: placedAt,
      paymentMethod: 'Cash on Delivery',
      address: address,
    );

    test('changes status while preserving the rest of the snapshot', () {
      final updated = order.copyWith(status: OrderStatus.shipped);

      expect(updated.status, OrderStatus.shipped);
      expect(updated.id, order.id);
      expect(updated.items, order.items);
      expect(updated.subtotal, order.subtotal);
      expect(updated.shipping, order.shipping);
      expect(updated.total, order.total);
      expect(updated.placedAt, placedAt);
      expect(updated.paymentMethod, order.paymentMethod);
      expect(updated.address, address);
    });

    test('changes address and keeps a null address when not supplied', () {
      final updated = order.copyWith(
        address: address.copyWith(city: 'Alexandria'),
      );
      expect(updated.address?.city, 'Alexandria');
      expect(updated.status, OrderStatus.placed);

      final noAddress = Order(
        id: 'ORD-2',
        items: const [],
        subtotal: Money.zero,
        shipping: Money.zero,
        total: Money.zero,
        status: OrderStatus.pending,
        placedAt: placedAt,
        paymentMethod: 'card',
      );
      expect(noAddress.copyWith(status: OrderStatus.paid).address, isNull);
    });
  });
}
