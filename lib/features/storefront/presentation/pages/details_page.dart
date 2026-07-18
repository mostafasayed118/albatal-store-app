import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/price_text.dart';
import '../widgets/product_image_placeholder.dart';
import '../widgets/quantity_stepper.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';
import '../cubit/products_data.dart';
import '../cubit/wishlist_cubit.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = products.firstWhere((x) => x.id == id, orElse: () => products.first);
    return BlocProvider(
      create: (_) => ProductDetailsCubit(),
      child: BlocBuilder<ProductDetailsCubit, DetailsState>(
        builder: (context, s) => Scaffold(
          appBar: AppBar(
            actions: [
              BlocBuilder<WishlistCubit, Set<String>>(
                builder: (_, w) {
                  final saved = w.contains(p.id);
                  return IconButton(
                    tooltip: saved ? l.removeFromWishlist : l.addToWishlist,
                    onPressed: () => context.read<WishlistCubit>().toggle(p.id),
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
                    color: saved ? Theme.of(context).colorScheme.error : null,
                  );
                },
              ),
              IconButton(
                tooltip: l.shareProduct,
                onPressed: () => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.shareLinkCopied))),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProductImagePlaceholder(
                imageColor: p.imageColor,
                imageAsset: p.imageAsset,
                constraints: const BoxConstraints.expand(height: 300),
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
              PriceText(
                p.price,
                style: TextStyle(
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
                showStrikeThrough: p.oldPrice != null,
                strikeThroughAmount: p.oldPrice,
              ),
              if (p.oldPrice != null) ...[
                const SizedBox(height: 8),
                Chip(label: Text(l.discountPercent(
                    ((p.oldPrice! - p.price) / p.oldPrice! * 100).round()))),
              ],
              const SizedBox(height: 20),
              Text(l.color),
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
              Text(l.length),
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
                  Text(l.quantity),
                  const Spacer(),
                  QuantityStepper(
                    quantity: s.quantity,
                    onChanged: (v) => context.read<ProductDetailsCubit>().quantity(v),
                  ),
                ],
              ),
              Card(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(l.expressDelivery),
                  subtitle: Text(l.expressDeliveryBody),
                ),
              ),
              if (p.description != null) ...[
                const SizedBox(height: 20),
                Text('Description',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(p.description!),
              ],
              if (p.composition != null || p.origin != null) ...[
                const SizedBox(height: 20),
                Text('Details',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (p.composition != null)
                  _InfoRow(icon: Icons.science_outlined, label: 'Composition', value: p.composition!),
                if (p.origin != null)
                  _InfoRow(icon: Icons.place_outlined, label: 'Origin', value: p.origin!),
              ],
              if (p.care != null) ...[
                const SizedBox(height: 20),
                Text('Care',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(p.care!),
              ],
            ],
          ),
          bottomNavigationBar: BottomActionButton(
            label: l.addToCart,
            icon: Icons.shopping_bag_outlined,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            onPressed: () {
              context.read<CartCubit>().add(p, color: s.color, length: s.length, quantity: s.quantity);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.addedToCart)));
            },
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: '$label: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface),
                  children: [
                    TextSpan(
                      text: value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
