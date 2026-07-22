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
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          money(amount, context: context),
          style:
              style ?? TextStyle(color: primary, fontWeight: FontWeight.bold),
        ),
        if (showStrikeThrough && strikeThroughAmount != null) ...[
          const SizedBox(width: 8),
          Text(
            money(strikeThroughAmount!, context: context),
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: .5),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}
