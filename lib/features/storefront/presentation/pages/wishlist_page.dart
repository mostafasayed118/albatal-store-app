import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/wishlist_cubit.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/wishlist_tile.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.wishlist)),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, ws) {
          if (ws.products.isEmpty && ws.ids.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<WishlistCubit>().resolveProducts(
                  context.read<CatalogCubit>().state.allProducts);
            });
          }
          if (ws.products.isEmpty) {
            return EmptyStateView(
              // A heart reads as "nothing saved yet" — clearer than a
              // warehouse/stock glyph for a wishlist.
              icon: Icons.favorite_border,
              title: l.noItemsFound,
              actionLabel: l.exploreCategories,
              onAction: () => context.go('/categories'),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ws.products.length,
              // Same width-aware delegate as Home/Catalog: 2 cols on phone,
              // 3 at ≥700, 4 at ≥1000.
              gridDelegate: productGridDelegateForWidth(constraints.maxWidth),
              itemBuilder: (_, i) => WishlistTile(product: ws.products[i]),
            ),
          );
        },
      ),
    );
  }
}
