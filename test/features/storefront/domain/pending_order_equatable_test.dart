import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:flutter_test/flutter_test.dart';

PendingOrder _pending({
  String orderId = 'ord-1',
  int total = 1000,
  OrderStatus status = OrderStatus.pending,
  bool retry = false,
}) =>
    PendingOrder(
      orderId: orderId,
      subtotal: const Money(900),
      shipping: const Money(100),
      total: Money(total),
      expiresAt: DateTime.parse('2026-09-04T00:00:00Z'),
      status: status,
      isIdempotentRetry: retry,
    );

void main() {
  group('PendingOrder equality', () {
    test('equal when every prop matches', () {
      expect(_pending(), _pending());
      expect(_pending().hashCode, _pending().hashCode);
    });

    test('differs on order id, money, status, or retry flag', () {
      expect(_pending(), isNot(_pending(orderId: 'ord-2')));
      expect(_pending(), isNot(_pending(total: 2000)));
      expect(_pending(), isNot(_pending(status: OrderStatus.placed)));
      expect(_pending(), isNot(_pending(retry: true)));
    });

    test('props lists every field in order', () {
      final order = _pending();

      expect(order.props, [
        'ord-1',
        const Money(900),
        const Money(100),
        const Money(1000),
        DateTime.parse('2026-09-04T00:00:00Z'),
        OrderStatus.pending,
        false,
      ]);
    });
  });
}
