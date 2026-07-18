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
    final steps = [
      (OrderStatus.placed, l.placed),
      (OrderStatus.shipped, l.shipped),
      (OrderStatus.delivered, l.delivered),
    ];
    final reached = steps.indexWhere((s) => s.$1 == status);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
