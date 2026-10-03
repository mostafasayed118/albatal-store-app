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
    final theme = Theme.of(context).textTheme;
    // 078: wholesale members see their negotiated list price as THE price
    // (injected into the product by the details cubit — only RLS-cleared
    // viewers carry it). Everyone else sees the catalog price unchanged.
    final isWholesalePrice = product.wholesalePrice != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: theme.headlineMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            // Stitch price: EGP-suffixed amount in label-md (labelLarge)
            // bold primary #003527 (spec §4), rendered in the reader's
            // locale by PriceText (audit UX-019). Intrinsic width: the
            // price is never truncated; the discount chip below flexes
            // instead.
            PriceText(
              product.effectiveBasePrice,
              style: theme.labelLarge?.copyWith(
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
        if (isWholesalePrice) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                context.l10n.wholesalePriceLabel,
                style:
                    theme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
