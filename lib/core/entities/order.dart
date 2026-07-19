import 'package:equatable/equatable.dart';

import 'address.dart';
import 'money.dart';
import 'product.dart';

/// Status of a placed order. Maps to the orders page tabs:
/// - [pending] / [placed] / [processing] / [shipped] → "Active" tab
/// - [delivered] → "Completed" tab
/// - [cancelled] → "Cancelled" tab
///
/// [pending] = created but not yet paid (server-side checkout flow).
/// [paid] = payment confirmed by webhook (transitions to [placed] or
/// [processing] for fulfillment).
enum OrderStatus { pending, placed, paid, processing, shipped, delivered, cancelled, refunded }

/// An immutable snapshot of a successfully placed order.
///
/// The [items], [address], and money fields are copies taken at placement time,
/// so a later change to the catalog or address book never rewrites history.
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
    this.address,
  });

  final String id;
  final List<CartItem> items;
  final Money subtotal;
  final Money shipping;
  final Money total;
  final OrderStatus status;
  final DateTime placedAt;
  final String paymentMethod;
  final Address? address;

  int get itemCount => items.fold(0, (v, i) => v + i.quantity);

  Order copyWith({OrderStatus? status, Address? address}) => Order(
        id: id,
        items: items,
        subtotal: subtotal,
        shipping: shipping,
        total: total,
        status: status ?? this.status,
        placedAt: placedAt,
        paymentMethod: paymentMethod,
        address: address ?? this.address,
      );

  @override
  List<Object?> get props => [
        id,
        items,
        subtotal,
        shipping,
        total,
        status,
        placedAt,
        paymentMethod,
        address
      ];
}
