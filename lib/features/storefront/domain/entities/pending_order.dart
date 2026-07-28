import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';

/// Lightweight result of creating a pending order server-side.
///
/// All monetary fields are the server-computed source of truth in
/// integer minor units — never trust the client for price, shipping,
/// or total. The [orderId] is the canonical DB row id to pass to the
/// payment layer. The [expiresAt] timestamp is when the order
/// auto-cancels if payment is not completed.
///
/// [isIdempotentRetry] is true when the server returned an existing
/// order created by a previous request with the same idempotency key
/// (no stock was decremented again).
final class PendingOrder extends Equatable {
  const PendingOrder({
    required this.orderId,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.expiresAt,
    this.status = 'pending',
    this.isIdempotentRetry = false,
  });

  final String orderId;
  final Money subtotal;
  final Money shipping;
  final Money total;
  final DateTime expiresAt;
  final String status;
  final bool isIdempotentRetry;

  @override
  List<Object?> get props => [
        orderId,
        subtotal,
        shipping,
        total,
        expiresAt,
        status,
        isIdempotentRetry
      ];
}
