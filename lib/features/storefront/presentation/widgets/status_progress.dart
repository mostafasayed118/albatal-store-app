import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/orders_cubit.dart';

/// Shows order status as ● ○ ○ progress dots.
class StatusProgress extends StatelessWidget {
  const StatusProgress({super.key, required this.status, required this.scheme});
  final OrderStatus status;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Four-stage lifecycle matching the Stitch order-tracking mockup
    // (Placed → Confirmed → Shipped → Delivered); `processing` is the
    // app/DB name for the Confirmed stage (order_status enum, migration
    // 001). Cancelled/refunded/expired have no progress track.
    final steps = [
      (OrderStatus.placed, l.placed),
      (OrderStatus.processing, l.processing),
      (OrderStatus.shipped, l.shipped),
      (OrderStatus.delivered, l.delivered),
    ];
    final reached = switch (status) {
      // pending (created, not yet paid) still shows stage 1 reached.
      OrderStatus.pending => 0,
      OrderStatus.paid => 1,
      _ => steps.indexWhere((s) => s.$1 == status),
    };
    // Wrap (was a Row): at the default scale the four stages fit on one
    // run and spaceBetween distributes them exactly like the old Row;
    // at large text scales (1.4×) the stages flow onto extra runs
    // instead of overflowing the card row.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < steps.length; i++)
          Text(
            '${i <= reached ? '●' : '○'} ${steps[i].$2}',
            style: TextStyle(
              color: i <= reached
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: .5),
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
