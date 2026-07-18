import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../data/products_data.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/product_details_cubit.dart';
import '../widgets/bottom_action_button.dart';
import '../widgets/image_gallery.dart';
import '../widgets/info_card.dart';
import '../widgets/price_text.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/related_card.dart';
import '../widgets/size_guide_sheet.dart';
import '../widgets/stock_badge.dart';
import '../widgets/wishlist_toggle_icon.dart';

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return BlocProvider(
      create: (_) => ProductDetailsCubit()..loadProduct(id, products),
      child: BlocBuilder<ProductDetailsCubit, DetailsState>(
        builder: (context, s) {
          final p = s.product;
          if (p == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(p.category),
              actions: [
                WishlistToggleIcon(productId: p.id),
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
                ImageGallery(product: p),
                const SizedBox(height: 20),
                _NameAndPrice(product: p, l: l, scheme: scheme),
                if (p.reviewCount > 0) ...[
                  const SizedBox(height: 8),
                  _RatingStars(product: p, scheme: scheme),
                ],
                const SizedBox(height: 20),
                _VariantSelector(product: p, state: s),
                const SizedBox(height: 20),
                _DeliveryInfo(l: l, scheme: scheme),
                if (p.description != null) ...[
                  const SizedBox(height: 20),
                  Text(l.description,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(p.description!),
                ],
                _ProductDetails(product: p, l: l),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => showSizeGuide(context),
                  icon: const Icon(Icons.straighten, size: 18),
                  label: Text(l.sizeGuide),
                ),
                if (s.relatedProducts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(l.relatedProducts,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: s.relatedProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => RelatedCard(
                        product: s.relatedProducts[i],
                        onTap: () =>
                            context.push('/product/${s.relatedProducts[i].id}'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
            bottomNavigationBar:
                _AddToCartButton(state: s, l: l, scheme: scheme),
          );
        },
      ),
    );
  }
}

class _NameAndPrice extends StatelessWidget {
  const _NameAndPrice(
      {required this.product, required this.l, required this.scheme});
  final dynamic product;
  final dynamic l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            PriceText(
              product.price,
              style: TextStyle(
                  fontSize: 22,
                  color: scheme.primary,
                  fontWeight: FontWeight.bold),
              showStrikeThrough: product.oldPrice != null,
              strikeThroughAmount: product.oldPrice,
            ),
            if (product.discountPercent != null) ...[
              const SizedBox(width: 8),
              Chip(
                  label: Text(
                      context.l10n.discountPercent(product.discountPercent!))),
            ],
          ],
        ),
      ],
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.product, required this.scheme});
  final dynamic product;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(
          5,
          (i) => Icon(
            i < product.rating.round() ? Icons.star : Icons.star_border,
            size: 18,
            color: scheme.secondary,
          ),
        ),
        const SizedBox(width: 6),
        Text('${product.rating}',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: scheme.onSurface)),
        Text(' (${product.reviewCount})',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _VariantSelector extends StatelessWidget {
  const _VariantSelector({required this.product, required this.state});
  final dynamic product;
  final DetailsState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ProductDetailsCubit>();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.color, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.colors
                        .map((x) => ChoiceChip(
                              label: Text(x),
                              selected: state.color == x,
                              onSelected: (_) => cubit.color(x),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StockBadge(stock: state.stock, l: l),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.length,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.sizes
                        .map((x) => ChoiceChip(
                              label: Text(x),
                              selected: state.length == x,
                              onSelected: (_) => cubit.length(x),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(l.quantity, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            QuantityStepper(
              quantity: state.quantity,
              onChanged: (v) => cubit.quantity(v),
              max: state.stock,
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  const _DeliveryInfo({required this.l, required this.scheme});
  final dynamic l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoCard(
          icon: Icons.local_shipping_outlined,
          title: l.expressDelivery,
          subtitle: l.expressDeliveryBody,
          color: scheme.primary,
        ),
        const SizedBox(height: 8),
        InfoCard(
          icon: Icons.replay_outlined,
          title: l.returns,
          subtitle: l.returnsBody,
          color: scheme.secondary,
        ),
      ],
    );
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({required this.product, required this.l});
  final dynamic product;
  final dynamic l;

  @override
  Widget build(BuildContext context) {
    if (product.composition == null &&
        product.origin == null &&
        product.care == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.composition != null || product.origin != null) ...[
          const SizedBox(height: 20),
          Text(l.details, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (product.composition != null)
            InfoRow(
                icon: Icons.science_outlined,
                label: l.composition,
                value: product.composition!),
          if (product.origin != null)
            InfoRow(
                icon: Icons.place_outlined,
                label: l.origin,
                value: product.origin!),
        ],
        if (product.care != null) ...[
          const SizedBox(height: 20),
          Text(l.care, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(product.care!),
        ],
      ],
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton(
      {required this.state, required this.l, required this.scheme});
  final DetailsState state;
  final dynamic l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final p = state.product!;
    return BottomActionButton(
      label: state.inStock ? l.addToCart : l.outOfStock,
      icon: Icons.shopping_bag_outlined,
      backgroundColor: state.inStock ? scheme.secondary : scheme.outline,
      onPressed: state.inStock
          ? () {
              context.read<CartCubit>().add(p,
                  color: state.color,
                  length: state.length,
                  quantity: state.quantity);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.addedToCart)));
            }
          : null,
    );
  }
}
