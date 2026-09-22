import 'package:flutter/material.dart';

/// Heart glyph split out so the 44px hit area stays constant while only
/// the glyph rebuilds on wishlist toggles.
///
/// Extracted from `stitch_product_grid_card.dart` (was private
/// `_WishlistHeart`); public so other cards can reuse the exact glyph.
class WishlistHeart extends StatelessWidget {
  const WishlistHeart({super.key, required this.isWishlisted});
  final bool isWishlisted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      isWishlisted ? Icons.favorite : Icons.favorite_border,
      size: 20,
      color: isWishlisted ? scheme.error : scheme.onSurfaceVariant,
    );
  }
}
