import 'package:flutter/material.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/money_copy.dart';

/// A price (optionally with a struck-through original) rendered in the
/// shopper's locale.
///
/// Formatting goes through [moneyText] — the localized formatter — rather
/// than `Money.format()`, so an Arabic build shows Arabic-Indic digits
/// and the Arabic pound symbol (audit UX-019). Whole amounts carry no
/// decimals, fractional piasters keep two (the app's convention, see
/// [moneyText]).
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
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          moneyText(l10n, amount),
          style: style ??
              textTheme.labelLarge?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700),
        ),
        if (showStrikeThrough && strikeThroughAmount != null) ...[
          const SizedBox(width: 8),
          Text(
            moneyText(l10n, strikeThroughAmount!),
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
