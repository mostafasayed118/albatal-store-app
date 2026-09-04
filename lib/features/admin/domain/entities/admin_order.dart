import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';

/// Fulfillment status of an admin-visible order.
///
/// Mirrors the `order_status` DB enum. Stored as a dedicated enum so the
/// cubit/pages switch on typed values instead of raw strings; unknown
/// server values degrade to [AdminOrderStatus.unknown] instead of
/// throwing at map time.
enum AdminOrderStatus {
  pending,
  placed,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded,
  unknown;

  /// Parses a raw DB value; never throws — null, non-string, and
  /// unrecognized values all become [AdminOrderStatus.unknown].
  static AdminOrderStatus fromName(Object? raw) {
    if (raw is! String) return unknown;
    for (final s in AdminOrderStatus.values) {
      if (s != unknown && s.name == raw) return s;
    }
    return unknown;
  }

  /// Canonical DB string (unknown serializes as its raw input; callers
  /// that must send a status never receive [unknown] from the UI flows
  /// guarded by [AdminOrderDetailActions]).
  String get dbValue => name;
}

/// A single line item of an admin-visible order, as read from the
/// `order_items` table joined into the order detail payload.
final class AdminOrderItem extends Equatable {
  const AdminOrderItem({
    required this.productName,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final String size;
  final String color;
  final int quantity;
  final Money unitPrice;

  @override
  List<Object?> get props => [productName, size, color, quantity, unitPrice];
}

/// An order as seen by the admin order queue / fulfillment screens.
///
/// This is a read model for the admin feature — intentionally distinct
/// from the storefront `Order` snapshot entity, which models the
/// customer's own receipt (full product snapshots, address). The admin
/// view carries the fields fulfillment workflows need: customer name,
/// item counts, tracking number, and the raw status transition source.
final class AdminOrder extends Equatable {
  const AdminOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.placedAt,
    this.customerName,
    this.paymentMethod,
    this.itemCount,
    this.items = const [],
    this.trackingNumber,
    this.address,
  });

  final String id;
  final AdminOrderStatus status;
  final Money total;
  final DateTime placedAt;

  /// Customer display name from the joined `profiles(full_name)`.
  /// Null when the queue query didn't join profiles or the name is blank.
  final String? customerName;

  final String? paymentMethod;

  /// Number of line items on the order. Present on queue rows (computed
  /// from the joined `order_items` array) and on detail views.
  final int? itemCount;

  /// Line items — only populated by the detail query (`order_items(*)`).
  final List<AdminOrderItem> items;

  final String? trackingNumber;

  /// Shipping address snapshot fields for the detail view.
  /// Null when the order has no snapshot.
  final AdminOrderAddress? address;

  /// Safe first 8 characters of the id for compact UI display.
  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  /// Whether the order can transition to `processing`.
  bool get canConfirm =>
      status == AdminOrderStatus.paid || status == AdminOrderStatus.placed;

  /// Whether the order can be cancelled.
  bool get canCancel => canConfirm || status == AdminOrderStatus.processing;

  /// Whether the order can be marked shipped.
  bool get canShip => status == AdminOrderStatus.processing;

  /// Whether the order can be marked delivered.
  bool get canDeliver => status == AdminOrderStatus.shipped;

  @override
  List<Object?> get props => [
        id,
        status,
        total,
        placedAt,
        customerName,
        paymentMethod,
        itemCount,
        items,
        trackingNumber,
        address,
      ];
}

/// Shipping address snapshot fields shown on the admin order detail view.
final class AdminOrderAddress extends Equatable {
  const AdminOrderAddress({
    required this.recipient,
    required this.line,
    required this.city,
    this.country = '',
  });

  final String recipient;
  final String line;
  final String city;
  final String country;

  /// One-line rendering for the detail card.
  String get singleLine => '$line, $city';

  @override
  List<Object?> get props => [recipient, line, city, country];
}
