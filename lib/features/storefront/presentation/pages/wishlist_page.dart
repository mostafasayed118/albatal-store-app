import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/wishlist_cubit.dart';
import '../cubit/products_data.dart';
import '../widgets/product_tile.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: BlocBuilder<WishlistCubit, Set<String>>(
          builder: (context, ids) {
            final p = products.where((x) => ids.contains(x.id)).toList();
            if (p.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text('No items found', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => context.go('/categories'), child: const Text('Explore Categories')),
                  ],
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: p.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemBuilder: (_, i) => ProductTile(p[i]),
            );
          },
        ),
      );
}
