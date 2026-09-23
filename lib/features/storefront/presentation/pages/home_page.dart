import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/responsive_shell.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/components/stitch/stitch_hero_carousel.dart';
import '../../../../shared/components/stitch/stitch_product_grid_card.dart';
import '../../../../shared/components/stitch/stitch_search_bar.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/iterable_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../catalog_status_guard.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/wishlist_cubit.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/home/flash_sale_card.dart';
import '../widgets/home/greeting_title.dart';
import '../widgets/home/home_helpers.dart';
import '../widgets/home/popular_header.dart';
import '../widgets/home/recent_queries.dart';
import '../widgets/home/section_header.dart';
import '../widgets/recently_viewed_strip.dart';

export '../widgets/home/home_helpers.dart' show homeBuildWhen, homeGreeting;

/// Home — Stitch reskin (spec §4/§5):
/// pill search → 180dp gold hero → circular category chips →
/// flash-sale row with live countdown → 2-col (.68) popular grid.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.clock});

  /// Injectable time source so greeting tests (and previews) can pin an
  /// hour of day; defaults to the wall clock.
  final DateTime Function()? clock;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Bind flash sale banner to server (T1). The 60s refresh poll is
    // cubit-owned (CatalogCubit._flashPollTimer) so it survives page
    // navigation and dies with the cubit, not with this widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogCubit>().loadFlashSales();
    });
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
        title: HomeGreetingTitle(clock: widget.clock),
        actions: [
          IconButton(
            tooltip: l.openSettings,
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.dark_mode_outlined),
            color: AppColors.gold,
          ),
        ],
      ),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        buildWhen: homeBuildWhen,
        builder: (context, state) {
          final catalog = context.read<CatalogCubit>();
          // loading/offline/error guards — shared with CatalogPage since
          // the 2026-09-21 dedupe.
          final guard = catalogStatusGuard(state, catalog);
          if (guard != null) return guard;
          // Flash sale binding (T1): server-driven. First active sale drives
          // the discount label (state.discountLabel); countdown ticks flow
          // on the cubit's flashCountdown stream, never through state.
          // Product resolved by product_id lookup with visible.first
          // fallback to keep hero populated even before sales load.
          final flashSale = state.flashSales.firstOrNull;
          final flashProduct = flashSale == null
              ? (state.visible.isEmpty ? null : state.visible.first)
              : state.findProductById(flashSale.productId) ??
                  (state.visible.isEmpty ? null : state.visible.first);
          final discountLabel = state.discountLabel;
          // ResponsiveShell caps width at 1200px on tablet/desktop. The
          // wishlist heart is isolated per grid item (audit P3): a
          // BlocSelector inside each itemBuilder means a wishlist toggle
          // rebuilds one card's heart, never the ~100-card grid.
          return ResponsiveShell(
            child: CustomScrollView(
              // Dismiss the search keyboard on scroll: an open IME
              // shrank the viewport into a 7.6px bottom overflow
              // (live-found 2026-09-04).
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsetsDirectional.all(16),
                  sliver: SliverList.list(
                    children: [
                      StitchSearchBar(
                        controller: _searchController,
                        onChanged: catalog.updateQuery,
                        // Localized hint — the component's English fallback
                        // would be announced to Arabic screen-reader users.
                        hintText: l.searchFabrics,
                        // Outer SliverPadding already gutters 16 — keep
                        // vertical rhythm only to avoid a 32px double inset.
                        padding:
                            const EdgeInsetsDirectional.symmetric(vertical: 8),
                      ),
                      if (state.filters.query.isEmpty &&
                          state.recentQueries.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        HomeRecentQueries(
                          queries: state.recentQueries,
                          onDelete: catalog.deleteRecentQuery,
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Stitch multi-slide hero (spec §4): the mockup's
                      // evergreen promo slide first, then up to three
                      // featured products (discounted → best-rated, from
                      // CatalogState.featuredProducts). Index dots included.
                      StitchHeroCarousel(
                        slides: [
                          StitchHeroSlide.promo(
                            eyebrow: l.newArrival,
                            title: l.newSilkCollection,
                            subtitle: l.percentOff,
                            ctaLabel: l.shopNow,
                            onTap: () => context.go(Routes.categories),
                          ),
                          for (final p in state.featuredProducts)
                            StitchHeroSlide.fromProduct(
                              p,
                              onTap: () => context.push(Routes.product(p.id)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      StitchCategoryChips(
                        selected: state.filters.category,
                        onSelect: catalog.select,
                        categories: state.categories,
                      ),
                    ],
                  ),
                ),
                if (flashProduct != null) ...[
                  SliverPadding(
                    padding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: HomeSectionHeader(
                        title: l.flashSale,
                        trailing: Text(
                          discountLabel,
                          style: TextStyle(
                            color: scheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.all(16),
                    // Countdown: the card subscribes to the cubit's
                    // flashCountdown broadcast stream so the 1Hz ticker
                    // only does work when a widget actually renders the
                    // remaining time (audit 2026-09-13 — the stream
                    // previously had zero subscribers).
                    sliver: SliverToBoxAdapter(
                      child: HomeFlashSaleCard(
                        product: flashProduct,
                        discountLabel: discountLabel,
                        countdown: catalog.flashCountdown,
                      ),
                    ),
                  ),
                ],
                // #3: recently-viewed strip — hides itself until the
                // shopper has actually viewed a product this lifecycle.
                const SliverPadding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: RecentlyViewedStrip()),
                ),
                SliverPadding(
                  padding:
                      const EdgeInsetsDirectional.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: HomePopularHeader(
                      title: l.popularProducts,
                      sort: state.filters.sort,
                      onSortSelected: catalog.selectSort,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(l.fabricsFound(state.visible.length)),
                  ),
                ),
                if (state.visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: CatalogEmptyState(
                        onClear: () {
                          _searchController.clear();
                          catalog.clearFilters();
                        },
                      ),
                    ),
                  )
                else
                  SliverLayoutBuilder(
                    builder: (context, constraints) => SliverPadding(
                      padding: const EdgeInsetsDirectional.all(16),
                      sliver: SliverGrid.builder(
                        gridDelegate: productGridDelegateForWidth(
                          constraints.crossAxisExtent,
                        ),
                        itemCount: state.visible.length,
                        itemBuilder: (_, index) {
                          final product = state.visible[index];
                          return BlocSelector<WishlistCubit, WishlistState,
                              bool>(
                            selector: (wishlist) =>
                                wishlist.ids.contains(product.id),
                            builder: (context, isWishlisted) =>
                                StitchProductGridCard(
                              product: product,
                              onTap: () =>
                                  context.push(Routes.product(product.id)),
                              onWishlist: () {
                                hapticTap();
                                context
                                    .read<WishlistCubit>()
                                    .toggle(product.id);
                              },
                              isWishlisted: isWishlisted,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
