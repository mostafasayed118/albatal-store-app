import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/wishlist_cubit.dart';

/// Shared heart icon that toggles a product's wishlist status.
///
/// Used by [ProductTile] and [DetailsPage] to avoid duplicating the
/// BlocBuilder + toggle logic. Reads [WishlistCubit] state and calls
/// [WishlistCubit.toggle] on tap.
class WishlistToggleIcon extends StatelessWidget {
  const WishlistToggleIcon({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<WishlistCubit, WishlistState>(
      builder: (_, ws) {
        final saved = ws.ids.contains(productId);
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: saved ? l.removeFromWishlist : l.addToWishlist,
          onPressed: () => context.read<WishlistCubit>().toggle(productId),
          icon: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            color: saved ? Theme.of(context).colorScheme.error : null,
          ),
        );
      },
    );
  }
}
