import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/wishlist_cubit.dart';

/// "Notify me when back in stock" toggle (task #5).
///
/// Shown on out-of-stock wishlist tiles and on the details page when the
/// selected variant has no stock. Toggling registers the product id in
/// the [BackInStockAlertStore] preset and confirms with a toast. The
/// per-product switch state is rebuilt via a BlocSelector so only this
/// row repaints on a toggle.
class BackInStockToggle extends StatelessWidget {
  const BackInStockToggle({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocSelector<WishlistCubit, WishlistState, bool>(
      selector: (s) => s.alertIds.contains(product.id),
      builder: (context, enabled) => Row(
        children: [
          Icon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_none,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.notifyWhenBackInStock,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            height: 32,
            child: Switch(
              value: enabled,
              onChanged: (v) {
                context
                    .read<WishlistCubit>()
                    .toggleBackInStockAlert(product.id, v);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(v
                        ? l.backInStockAlertOn(product.name)
                        : l.backInStockAlertOff),
                  ));
              },
            ),
          ),
        ],
      ),
    );
  }
}
