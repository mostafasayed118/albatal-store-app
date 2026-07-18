import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../../data/products_data.dart';
import '../cubit/wishlist_cubit.dart';
import 'product_image_placeholder.dart';
import 'quantity_stepper.dart';

/// A single cart item card with quantity controls, remove, and save-for-later.
///
/// Extracted from [CartPage] to keep the page's build method focused on
/// layout rather than per-item presentation. The dismiss-with-undo logic
/// lives here because it coordinates two cubits (CartCubit + WishlistCubit)
/// and owns the SnackBar lifecycle.
class CartItemTile extends StatelessWidget {
  const CartItemTile({super.key, required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      confirmDismiss: (_) async {
        final cart = context.read<CartCubit>();
        final product = item.product;
        final color = item.color;
        final length = item.length;
        final quantity = item.quantity;
        final itemKey = item.key;
        final name = product.name;
        cart.remove(itemKey);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l.remove} $name'),
              action: SnackBarAction(
                label: l.undo,
                onPressed: () => cart.add(product,
                    color: color, length: length, quantity: quantity),
              ),
            ),
          );
        }
        return false;
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductImagePlaceholder(
                imageColor: item.product.imageColor,
                imageAsset: item.product.imageAsset,
                constraints:
                    const BoxConstraints.tightFor(width: 72, height: 72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('${item.color} · ${item.length}'),
                    Text(money(item.product.price * item.quantity)),
                    QuantityStepper(
                      quantity: item.quantity,
                      onChanged: (q) =>
                          context.read<CartCubit>().update(item.key, q),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              context.read<CartCubit>().remove(item.key),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.error,
                          ),
                          child: Text(l.remove),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            context
                                .read<WishlistCubit>()
                                .toggle(item.product.id);
                            context.read<CartCubit>().remove(item.key);
                          },
                          icon: const Icon(Icons.bookmark_border, size: 16),
                          label: Text(l.saveForLater,
                              style: const TextStyle(fontSize: 12)),
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
    );
  }
}
