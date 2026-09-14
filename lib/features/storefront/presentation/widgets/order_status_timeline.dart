import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/entities/order.dart';
import '../../../../shared/extensions/build_context_x.dart';

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
      return _CancelledTerminal(scheme: scheme, label: l.cancelled);
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
          _StepRow(
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

/// One timeline row: status icon + connector rail, label, optional stamp.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.isFirst,
    required this.isLast,
    required this.isReached,
    required this.label,
    required this.timestamp,
    required this.scheme,
  });

  final bool isFirst;
  final bool isLast;
  final bool isReached;
  final String label;
  final DateTime? timestamp;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final iconColor =
        isReached ? scheme.primary : scheme.onSurface.withValues(alpha: .4);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              // Rail stubs keep the connector continuous between steps.
              if (!isFirst) Expanded(child: _rail()),
              Icon(
                isReached ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: iconColor,
              ),
              if (!isLast) Expanded(child: _rail()),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isReached
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: .5),
                          fontWeight:
                              isReached ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                  if (timestamp != null)
                    Text(
                      DateFormat('d MMM y, HH:mm', l.localeName)
                          .format(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: .6),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rail() => Container(
        width: 2,
        color: scheme.outlineVariant,
      );
}

/// Terminal row for cancelled/refunded/expired orders: no progress track,
/// error-colored marker. No timestamp — the backend has no per-state
/// timestamps, so nothing here may pretend to be a cancellation time.
class _CancelledTerminal extends StatelessWidget {
  const _CancelledTerminal({required this.scheme, required this.label});

  final ColorScheme scheme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cancel, size: 20, color: scheme.error),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
