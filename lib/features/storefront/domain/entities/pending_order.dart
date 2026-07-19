import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';

/// Lightweight result of creating a pending order server-side.
///
/// Only carries the fields the server actually returns: [orderId] (the DB
/// row id to pass to paymob-initiate), [total] (the server-computed total
/// in minor units — the source of truth, never trust the client), and
/// [expiresAt] (when the order auto-cancels if unpaid).
final class PendingOrder extends Equatable {
  const PendingOrder({
    required this.orderId,
    required this.total,
    required this.expiresAt,
  });

  final String orderId;
  final Money total;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [orderId, total, expiresAt];
}
