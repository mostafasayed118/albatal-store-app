import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import 'price_text.dart';

/// Product name, price, and discount chip.
class NameAndPrice extends StatelessWidget {
  const NameAndPrice({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            PriceText(
              product.price,
              style: TextStyle(
                  fontSize: 22,
                  color: scheme.primary,
                  fontWeight: FontWeight.bold),
              showStrikeThrough: product.oldPrice != null,
              strikeThroughAmount: product.oldPrice,
            ),
            if (product.discountPercent != null) ...[
              const SizedBox(width: 8),
              Chip(
                  label: Text(
                      context.l10n.discountPercent(product.discountPercent!))),
            ],
          ],
        ),
      ],
    );
  }
}
