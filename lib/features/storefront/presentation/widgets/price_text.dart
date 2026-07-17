import 'package:flutter/material.dart';

import '../cubit/products_data.dart';

class PriceText extends StatelessWidget {
  const PriceText(
    this.amount, {
    super.key,
    this.style,
    this.showStrikeThrough = false,
    this.strikeThroughAmount,
  });

  final double amount;
  final TextStyle? style;
  final bool showStrikeThrough;
  final double? strikeThroughAmount;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          money(amount),
          style:
              style ?? TextStyle(color: primary, fontWeight: FontWeight.bold),
        ),
        if (showStrikeThrough && strikeThroughAmount != null) ...[
          const SizedBox(width: 8),
          Text(
            money(strikeThroughAmount!),
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
