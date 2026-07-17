import 'package:al_batal_elite/features/storefront/presentation/widgets/bottom_action_button.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/price_text.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/product_image_placeholder.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/quantity_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';
import '../cubit/products_data.dart';
import '../cubit/wishlist_cubit.dart';


class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final p = products.firstWhere((x) => x.id == id, orElse: () => products.first);
    return BlocProvider(
      create: (_) => ProductDetailsCubit(),
      child: BlocBuilder<ProductDetailsCubit, DetailsState>(
        builder: (context, s) => Scaffold(
          appBar: AppBar(
            actions: [
              BlocBuilder<WishlistCubit, Set<String>>(
                builder: (_, w) => IconButton(
                  onPressed: () => context.read<WishlistCubit>().toggle(p.id),
                  icon: Icon(w.contains(p.id) ? Icons.favorite : Icons.favorite_border),
                ),
              ),
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied'))),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProductImagePlaceholder(
                imageColor: p.imageColor,
                constraints: const BoxConstraints.expand(height: 300),
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
              PriceText(
                p.price,
                style: TextStyle(fontSize: 22, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                showStrikeThrough: p.oldPrice != null,
                strikeThroughAmount: p.oldPrice,
              ),
              if (p.oldPrice != null) ...[
                const SizedBox(width: 8),
                const Chip(label: Text('-15%')),
              ],
              const SizedBox(height: 20),
              const Text('Color'),
              Wrap(
                spacing: 8,
                children: ['Emerald', 'Gold', 'Ivory']
                    .map((x) => ChoiceChip(
                          label: Text(x),
                          selected: s.color == x,
                          onSelected: (_) => context.read<ProductDetailsCubit>().color(x),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text('Length'),
              Wrap(
                spacing: 8,
                children: ['1m', '2m', '5m']
                    .map((x) => ChoiceChip(
                          label: Text(x),
                          selected: s.length == x,
                          onSelected: (_) => context.read<ProductDetailsCubit>().length(x),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Quantity'),
                  const Spacer(),
                  QuantityStepper(
                    quantity: s.quantity,
                    onChanged: (v) => context.read<ProductDetailsCubit>().quantity(v),
                  ),
                ],
              ),
              Card(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                child: const ListTile(
                  leading: Icon(Icons.local_shipping_outlined),
                  title: Text('Express Delivery'),
                  subtitle: Text('Delivered within 24–48 hours'),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomActionButton(
            label: 'Add to Cart',
            icon: Icons.shopping_bag_outlined,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            onPressed: () {
              context.read<CartCubit>().add(p, color: s.color, length: s.length, quantity: s.quantity);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to your cart')));
            },
          ),
        ),
      ),
    );
  }
}
