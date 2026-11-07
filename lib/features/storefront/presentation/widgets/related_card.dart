import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/money_copy.dart';
import 'product_image_placeholder.dart';

/// Compact card for a related product in horizontal list.
class RelatedCard extends StatelessWidget {
  const RelatedCard({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  /// Card height at the current text scale; the horizontal strip sizes
  /// itself from this so a taller card is never clipped by a fixed box.
  static double heightFor(BuildContext context) =>
      (140 + 60 * MediaQuery.textScalerOf(context).scale(1))
          .clamp(200.0, 280.0)
          .toDouble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: product.name,
      child: SizedBox(
        width: 140,
        height: heightFor(context),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // Decode budget (audit P4): the image slot is 140px
                  // wide — 280px ≈ 2x covers high-dpr phones without
                  // paying the 720px card default for a thumbnail strip.
                  child: ProductImagePlaceholder(
                    imageColor: product.imageColor,
                    imageAsset: product.imageAsset,
                    constraints: const BoxConstraints.expand(),
                    cacheExtent: 280,
                    size: 36,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        moneyText(context.l10n, product.price),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
