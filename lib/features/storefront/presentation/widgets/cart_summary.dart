import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
import '../../../../shared/extensions/build_context_x.dart';
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
            _row(context, l.subtotal, money(state.subtotal)),
            _row(context, l.shipping, money(state.shipping)),
            const Divider(),
            _row(context, l.total, money(state.total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(value,
                style: (bold
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.bodyMedium)
                    ?.copyWith(
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      );
}
