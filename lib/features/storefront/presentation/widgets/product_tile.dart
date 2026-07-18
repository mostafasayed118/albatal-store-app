import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import 'price_text.dart';
import 'product_image_placeholder.dart';
import 'wishlist_toggle_icon.dart';

class ProductTile extends StatelessWidget {
  const ProductTile(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context) => Card(
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
                imageAsset: product.imageAsset,
              ),
              const SizedBox(height: 10),
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  PriceText(product.price),
                  const Spacer(),
                  WishlistToggleIcon(productId: product.id),
                ],
              ),
            ],
          ),
        ),
      ),
    );
}

