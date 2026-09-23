import 'package:flutter/material.dart';

import '../../../../../core/entities/money.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/l10n/money_copy.dart';

/// Single server-total row used by the checkout totals card.
final class CheckoutServerTotalRow extends StatelessWidget {
  const CheckoutServerTotalRow(
      {super.key, required this.label, required this.value});
  final String label;
  final Money? value;

  @override
  Widget build(BuildContext context) {
    // Bound to a local before the null test: a public final field does not
    // participate in type promotion, so `moneyText(..., value)` inside the
    // ternary would still see `Money?`.
    final amount = value;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(amount == null ? '--' : moneyText(context.l10n, amount),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
