import 'package:equatable/equatable.dart';

import 'product.dart';

/// Status of a placed order. Maps to the orders page tabs:
/// - [placed] / [shipped] → "Active" tab
/// - [delivered] → "Completed" tab
/// - [cancelled] → "Cancelled" tab
enum OrderStatus { placed, shipped, delivered, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get name => switch (this) {
        OrderStatus.placed => 'Placed',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };
}

/// An immutable snapshot of a successfully placed order.
///
/// The [items] and money fields are copies taken at placement time, so a later
/// change to the catalog (price edit, product removal) never rewrites history.
/// This is the same ownership reasoning as a real receipt: the line items are
/// frozen the moment the order is confirmed.
final class Order extends Equatable {
  const Order({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.status,
    required this.placedAt,
    required this.paymentMethod,
  });

  final String id;
  final List<CartItem> items;
  final double subtotal;
  final double shipping;
  final double total;
  final OrderStatus status;
  final DateTime placedAt;
  final String paymentMethod;

  int get itemCount => items.fold(0, (v, i) => v + i.quantity);

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        items: items,
        subtotal: subtotal,
        shipping: shipping,
        total: total,
        status: status ?? this.status,
        placedAt: placedAt,
        paymentMethod: paymentMethod,
      );

  @override
  List<Object?> get props =>
      [id, items, subtotal, shipping, total, status, placedAt, paymentMethod];
}
