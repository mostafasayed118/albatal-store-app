import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/utils/app_date_formats.dart';

/// One timeline row: status icon + connector rail, label, optional stamp.
///
/// Extracted from `order_status_timeline.dart` verbatim (was private
/// `_StepRow`).
class TimelineStepRow extends StatelessWidget {
  const TimelineStepRow({
    super.key,
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
                      AppDateFormats.dayMonthYearTime(l.localeName)
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
