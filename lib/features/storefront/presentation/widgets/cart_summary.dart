import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/money_copy.dart';
import '../../../../shared/theme/app_colors.dart';
import '../cubit/cart_cubit.dart';

class CartSummary extends StatelessWidget {
  const CartSummary(this.state, {super.key});
  final CartState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          children: [
            _row(context, l.subtotal, moneyText(l, state.subtotal)),
            // Premium perk (migration 047): the server zeroes shipping for
            // premium members; show the perk, not a zero amount.
            if (state.isPremiumMember)
              _row(
                context,
                l.shipping,
                l.freeShipping,
                valueColor: AppColors.gold,
              )
            else
              _row(context, l.shipping, moneyText(l, state.shipping)),
            const Divider(),
            _row(context, l.total, moneyText(l, state.total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
          {bool bold = false, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
        child: Row(
          children: [
            // Expanded label (was a Spacer): identical layout at the
            // default scale, but at large text scales the label
            // ellipsizes instead of pushing the amount off-card. Money
            // values stay fully visible.
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            Text(value,
                style: (bold
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.bodyMedium)
                    ?.copyWith(
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        color: valueColor)),
          ],
        ),
      );
}
