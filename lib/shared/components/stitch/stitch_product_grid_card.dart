import 'package:flutter/material.dart';

import '../../../core/entities/product.dart';
import '../app_image.dart';

/// Stitch 2-col product grid card — surface, outlineVariant border, square media.
///
/// Tokens: Card radius 16, border outlineVariant 1dp, inner media
/// square 1:1, favorite 20dp heart top-end, EdgeInsetsDirectional,
/// InkSparkle via Card InkWell, heart uses InkWell circle.
class StitchProductGridCard extends StatelessWidget {
  const StitchProductGridCard({
    super.key,
    required this.product,
    this.onTap,
    this.onWishlist,
    this.isWishlisted = false,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onWishlist;
  final bool isWishlisted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return RepaintBoundary(
      child: Card(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media 1:1
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Color(product.imageColor),
                      child: AppImage(
                        source: product.imageAsset,
                        fit: BoxFit.cover,
                        cacheWidth: 420,
                        cacheHeight: 420,
                        placeholder: const Icon(
                          Icons.texture,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    // Wishlist heart top-end
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: Material(
                        color: scheme.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onWishlist,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              isWishlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: isWishlisted
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.price.format(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (product.oldPrice != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              product.oldPrice!.format(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
