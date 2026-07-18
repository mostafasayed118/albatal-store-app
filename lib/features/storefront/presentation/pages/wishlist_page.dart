import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/products_data.dart';
import '../cubit/wishlist_cubit.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/price_text.dart';
import '../widgets/product_image_placeholder.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.wishlist)),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, ws) {
          final p = products.where((x) => ws.ids.contains(x.id)).toList();
          if (p.isEmpty) {
            return EmptyStateView(
              icon: Icons.inventory_2_outlined,
              title: l.noItemsFound,
              actionLabel: l.exploreCategories,
              onAction: () => context.go('/categories'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: p.length,
            gridDelegate: productGridDelegate,
            itemBuilder: (_, i) => _WishlistTile(product: p[i]),
          );
        },
      ),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  const _WishlistTile({required this.product});
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
