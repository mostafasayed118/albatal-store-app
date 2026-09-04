import 'package:flutter/material.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/utils/currency.dart';

class PriceText extends StatelessWidget {
  const PriceText(
    this.amount, {
    super.key,
    this.style,
    this.showStrikeThrough = false,
    this.strikeThroughAmount,
  });

  final Money amount;
  final TextStyle? style;
  final bool showStrikeThrough;
  final Money? strikeThroughAmount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          money(amount),
          style: style ??
              textTheme.labelLarge?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700),
        ),
        if (showStrikeThrough && strikeThroughAmount != null) ...[
          const SizedBox(width: 8),
          Text(
            money(strikeThroughAmount!),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: .5),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}
