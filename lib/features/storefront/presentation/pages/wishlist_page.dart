import 'package:al_batal_elite/features/storefront/presentation/widgets/empty_state_view.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/products_data.dart';
import '../cubit/wishlist_cubit.dart';


class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: BlocBuilder<WishlistCubit, Set<String>>(
          builder: (context, ids) {
            final p = products.where((x) => ids.contains(x.id)).toList();
            if (p.isEmpty) {
              return EmptyStateView(
                icon: Icons.inventory_2_outlined,
                title: 'No items found',
                actionLabel: 'Explore Categories',
                onAction: () => context.go('/categories'),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: p.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .68,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12),
              itemBuilder: (_, i) => ProductTile(p[i]),
            );
          },
        ),
      );
}
