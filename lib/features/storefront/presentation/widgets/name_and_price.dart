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
            // Stitch price: EGY-suffixed amount in label-md (labelLarge)
            // bold primary #003527 (spec §4). Intrinsic width: the price
            // is never truncated; the discount chip below flexes instead.
            PriceText(
              product.price,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
              showStrikeThrough: product.oldPrice != null,
              strikeThroughAmount: product.oldPrice,
            ),
            if (product.discountPercent != null) ...[
              const SizedBox(width: 8),
              // Flexible chip: at large text scales (1.4×) it shrinks
              // (label ellipsizes) instead of pushing the price row past
              // the viewport; full-size at the default scale.
              Flexible(
                child: Chip(
                    label: Text(
                        context.l10n.discountPercent(product.discountPercent!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
