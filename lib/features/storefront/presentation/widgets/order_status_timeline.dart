import 'package:flutter/material.dart';

import '../../../../core/entities/order.dart';
import '../../../../shared/extensions/build_context_x.dart';
import 'cancelled_terminal.dart';
import 'step_row.dart';

/// Visual order-status timeline: Placed → Confirmed → Shipped → Delivered,
/// with Cancelled/refunded/expired rendered as a single terminal row.
///
/// Status mapping mirrors [StatusProgress] (the compact dots): `processing`
/// is the app/DB name for the Confirmed stage (order_status enum, migration
/// 001), and `paid` means the payment webhook already confirmed the order.
///
/// Per-step timestamps are optional. The orders API currently exposes only
/// [Order.placedAt], so later steps render state-only until the backend
/// grows per-step timestamps — every [DateTime?] degrades gracefully.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.status,
    required this.scheme,
    this.placedAt,
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
  });

  final OrderStatus status;
  final ColorScheme scheme;

  /// Per-step timestamps. Null steps render without a timestamp.
  final DateTime? placedAt;
  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  /// Index of the furthest reached lifecycle step, or -1 for the
  /// cancelled terminal states (no progress track).
  static int _reachedStep(OrderStatus status) => switch (status) {
        // pending (created, not yet paid) still reaches stage 1.
        OrderStatus.pending || OrderStatus.placed => 0,
        OrderStatus.paid || OrderStatus.processing => 1,
        OrderStatus.shipped => 2,
        OrderStatus.delivered => 3,
        OrderStatus.cancelled ||
        OrderStatus.refunded ||
        OrderStatus.expired =>
          -1,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isCancelled = _reachedStep(status) < 0;
    if (isCancelled) {
      return CancelledTerminal(scheme: scheme, label: l.cancelled);
    }

    final steps = <(int, String, DateTime?)>[
      (0, l.placed, placedAt),
      // DB `processing` == the Confirmed lifecycle stage.
      (1, l.confirmed, confirmedAt),
      (2, l.shipped, shippedAt),
      (3, l.delivered, deliveredAt),
    ];
    final reached = _reachedStep(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          TimelineStepRow(
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            isReached: steps[i].$1 <= reached,
            label: steps[i].$2,
            timestamp: steps[i].$3,
            scheme: scheme,
          ),
      ],
    );
  }
}
