import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/entities/product.dart';

/// Stitch flash-sale row card — 120dp, image left, badge + CTA.
///
/// Token map: Card surface white, outlineVariant 1dp border, radius 16,
/// badge `secondaryContainer` #FE932C on `secondary` #904D00 context,
/// internal image radius 8 (control), EdgeInsetsDirectional + InkSparkle.
class StitchFlashSaleCard extends StatelessWidget {
  const StitchFlashSaleCard({
    super.key,
    required this.product,
    this.discountLabel = '-15%',
    this.remaining,
    this.onAdd,
    this.onTap,
  });

  final Product product;
  final String discountLabel;
  final Duration? remaining;
  final VoidCallback? onAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Row(
              children: [
                // Image 90×90, control radius 8
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Color(product.imageColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.imageAsset == null
                      ? const Icon(Icons.texture, color: Colors.white, size: 28)
                      : product.imageAsset!.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: product.imageAsset!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Color(product.imageColor),
                                child: const Icon(Icons.texture,
                                    color: Colors.white, size: 28),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                  Icons.texture,
                                  color: Colors.white,
                                  size: 28),
                            )
                          : Image.asset(
                              product.imageAsset!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.texture,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge + name row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              discountLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (remaining != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatRemaining(remaining!),
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.price.format(),
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 32dp add FAB — secondary / gold semantic
                Material(
                  color: scheme.secondary,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onAdd,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
