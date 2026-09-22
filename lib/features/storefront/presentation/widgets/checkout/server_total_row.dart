import 'package:flutter/material.dart';

import '../../../../../core/entities/money.dart';

/// Single server-total row used by the checkout totals card.
final class CheckoutServerTotalRow extends StatelessWidget {
  const CheckoutServerTotalRow(
      {super.key, required this.label, required this.value});
  final String label;
  final Money? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value?.format() ?? '--',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
