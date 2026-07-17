import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../cubit/wishlist_cubit.dart';
import 'price_text.dart';
import 'product_image_placeholder.dart';

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
                ProductImagePlaceholder(imageColor: product.imageColor),
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
                    BlocBuilder<WishlistCubit, Set<String>>(
                      builder: (_, ids) => IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            context.read<WishlistCubit>().toggle(product.id),
                        icon: Icon(
                          ids.contains(product.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: ids.contains(product.id) ? Colors.red : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
