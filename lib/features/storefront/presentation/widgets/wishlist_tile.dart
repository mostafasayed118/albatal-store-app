import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/wishlist_cubit.dart';
import 'back_in_stock_toggle.dart';
import 'price_text.dart';
import 'product_image_placeholder.dart';

/// Wishlist grid tile with move-to-cart button.
class WishlistTile extends StatelessWidget {
  const WishlistTile({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.product(product.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square media fills the leftover height (single flex child):
              // the text block cannot squeeze it to nothing, and no Spacer
              // competes with it for the free space.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ProductImagePlaceholder(
                        imageColor: product.imageColor,
                        imageAsset: product.imageAsset,
                        cacheExtent: 360,
                        constraints: const BoxConstraints.expand()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              // At 2.0x the formatted amount is wider than the cell; scale
              // it down instead of letting the row overflow the tile.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: PriceText(product.price),
              ),
              // Task #5: out-of-stock wishlist items offer the
              // back-in-stock alert toggle in place of move-to-cart.
              if (product.inStock)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      // Narrow cell: the default 24dp side padding leaves the
                      // label one unbreakable word too little room at 2.0x.
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    onPressed: () {
                      context.read<CartCubit>().add(product);
                      context.read<WishlistCubit>().toggle(product.id);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.movedToCart)));
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: Text(
                      l.moveToCart,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
              else
                BackInStockToggle(product: product),
            ],
          ),
        ),
      ),
    );
  }
}
