import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/wishlist_cubit.dart';
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
        onTap: () => context.push('/product/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImagePlaceholder(
                  imageColor: product.imageColor,
                  imageAsset: product.imageAsset),
              const SizedBox(height: 8),
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              PriceText(product.price),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    context.read<CartCubit>().add(product);
                    context.read<WishlistCubit>().toggle(product.id);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l.movedToCart)));
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label:
                      Text(l.moveToCart, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
