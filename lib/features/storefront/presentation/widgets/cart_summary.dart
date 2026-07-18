import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/products_data.dart';

class CartSummary extends StatelessWidget {
  const CartSummary(this.state, {super.key});
  final CartState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(l.subtotal, money(state.subtotal)),
            _row(l.shipping, money(state.shipping)),
            const Divider(),
            _row(l.total, money(state.total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label),
            const Spacer(),
            Text(value,
                style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          ],
        ),
      );
}
