import 'package:flutter/material.dart';

import '../../../core/entities/product.dart';
import '../../components/feedback.dart';
import '../../extensions/build_context_x.dart';
import '../../l10n/money_copy.dart';
import '../../theme/contrast.dart';
import '../app_card.dart';
import '../app_image.dart';
import 'wishlist_heart.dart';

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
    final l = context.l10n;
    // §17: screen readers hear one coherent card — name, price and
    // availability — instead of a scatter of unrelated texts.
    return Semantics(
      container: true,
      button: true,
      label: '${product.name}, ${moneyText(l, product.price)}',
      child: RepaintBoundary(
        child: AppCard(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media flexes to absorb the cell height left over after
                // the text block. The text block's intrinsic height scales
                // with the user's font size, so a fixed square overflowed
                // by 7.6px on a 360dp device (device-found 2026-09-13);
                // BoxFit.cover degrades the crop instead of the layout.
                Expanded(
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
                          placeholder: Icon(
                            Icons.texture,
                            color: onSwatchColor(Color(product.imageColor)),
                            size: 32,
                          ),
                        ),
                      ),
                      // Wishlist heart top-end — 44px touch target with an
                      // accessible name (action + product, selected state).
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Semantics(
                          button: true,
                          selected: isWishlisted,
                          label:
                              '${isWishlisted ? l.removeFromWishlistAction : l.addToWishlist}, ${product.name}',
                          child: Material(
                            color: scheme.surface.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onWishlist == null
                                  ? null
                                  : () {
                                      hapticTap();
                                      onWishlist!();
                                    },
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: WishlistHeart(
                                    isWishlisted: isWishlisted,
                                  ),
                                ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Wrap, not Row. A Row splits the cell's inner
                      // width evenly between the two amounts, so the price
                      // was silently clipped as soon as a discount was
                      // present and the amount got wide: measured 66.9dp of
                      // text in a 66.0dp slot at the default scale and
                      // 93.2dp at 1.4x (real Inter, 158dp cell). Each amount
                      // now takes the width it needs, and the struck-through
                      // old price drops to a second line only when it no
                      // longer fits beside the price — identical at the
                      // default scale, nothing clipped at large scales. The
                      // media above is Expanded, so an extra line shrinks
                      // the image instead of overflowing the cell.
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            moneyText(l, product.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (product.oldPrice != null)
                            Text(
                              moneyText(l, product.oldPrice!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
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
