import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/components/stitch/stitch_flash_sale_card.dart';
import '../../../../shared/components/stitch/stitch_product_grid_card.dart';
import '../../../../shared/components/stitch/stitch_search_bar.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/wishlist_cubit.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/promo_banner.dart';

/// Home — Stitch reskin (spec §4/§5):
/// pill search → 180dp gold hero → circular category chips →
/// flash-sale row with live countdown → 2-col (.68) popular grid.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Flash sale countdown driving StitchFlashSaleCard (spec §5 data flow).
    // flashEnd is client-side placeholder; TODO: drive from Supabase flash_sales table
    context.read<CatalogCubit>().startFlashSale(
          end: DateTime.now().add(
            const Duration(hours: 2, minutes: 45, seconds: 12),
          ),
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.goodMorning,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: .6))),
            Text(
              l.brandName,
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                  color: scheme.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.openSettings,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, state) {
          final catalog = context.read<CatalogCubit>();
          if (state.status == CatalogStatus.loading ||
              state.status == CatalogStatus.initial) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == CatalogStatus.error) {
            return FeedbackView(
              type: FeedbackViewType.error,
              onAction: catalog.load,
            );
          }
          final flashProduct =
              state.visible.isEmpty ? null : state.visible.first;
          return ListView(
            padding: const EdgeInsetsDirectional.all(16),
            children: [
              StitchSearchBar(
                controller: _searchController,
                onChanged: catalog.updateQuery,
              ),
              if (state.query.isEmpty && state.recentQueries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final q in state.recentQueries)
                      Chip(
                        label: Text(q),
                        avatar: const Icon(Icons.history, size: 16),
                        onDeleted: () => catalog.deleteRecentQuery(q),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // Hero fallback: StitchHeroCarousel is not built yet; PromoBanner
              // keeps the 180dp gold-CTA contract until it lands.
              const PromoBanner(),
              const SizedBox(height: 24),
              StitchCategoryChips(
                selected: state.category,
                onSelect: catalog.select,
                categories: state.categories,
              ),
              const SizedBox(height: 24),
              if (flashProduct != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(l.flashSale,
                          style:
                              Theme.of(context).textTheme.titleLarge),
                    ),
                    Text(
                      '-15%',
                      style: TextStyle(
                        color: scheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StitchFlashSaleCard(
                  product: flashProduct,
                  discountLabel: '-15%',
                  remaining: state.flashRemaining,
                  onAdd: () => context.read<CartCubit>().add(flashProduct),
                  onTap: () => context.push('/product/${flashProduct.id}'),
                ),
                const SizedBox(height: 24),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(l.popularProducts,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  PopupMenuButton<CatalogSort>(
                    tooltip: l.sortProducts,
                    initialValue: state.sort,
                    onSelected: catalog.selectSort,
                    itemBuilder: (_) => CatalogSort.values
                        .map((sort) => PopupMenuItem(
                            value: sort, child: Text(sort.label)))
                        .toList(),
                    child: Chip(
                      avatar: const Icon(Icons.sort, size: 18),
                      label: Text(state.sort.label),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l.fabricsFound(state.visible.length)),
              const SizedBox(height: 12),
              if (state.visible.isEmpty)
                CatalogEmptyState(
                  onClear: () {
                    _searchController.clear();
                    catalog.clearFilters();
                  },
                )
              else
                // Wishlist state drives each card's heart (spec §5 data flow).
                // TODO(audit): consider SliverGrid or visible.take(20) for 100+ items
                BlocBuilder<WishlistCubit, WishlistState>(
                  builder: (context, wishlist) {
                    // Cap Popular grid to 20 to prevent jank at 100+ products.
                    final displayProducts = state.visible.take(20).toList();
                    return RepaintBoundary(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayProducts.length,
                        gridDelegate: productGridDelegate,
                        itemBuilder: (_, index) {
                          final product = displayProducts[index];
                        return StitchProductGridCard(
                          product: product,
                          onTap: () =>
                              context.push('/product/${product.id}'),
                          onWishlist: () => context
                              .read<WishlistCubit>()
                              .toggle(product.id),
                          isWishlisted:
                              wishlist.ids.contains(product.id),
                        );
                      },
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
