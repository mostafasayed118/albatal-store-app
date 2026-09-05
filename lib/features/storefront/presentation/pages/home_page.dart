import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/components/responsive_shell.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/components/stitch/stitch_flash_sale_card.dart';
import '../../../../shared/components/stitch/stitch_product_grid_card.dart';
import '../../../../shared/components/stitch/stitch_search_bar.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/extensions/iterable_x.dart';
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
  const HomePage({super.key, this.clock});

  /// Injectable time source so greeting tests (and previews) can pin an
  /// hour of day; defaults to the wall clock.
  final DateTime Function()? clock;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _searchController;
  Timer? _flashPollTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Bind flash sale banner to server (T1). Initial load + poll every 60s.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogCubit>().loadFlashSales();
    });
    _flashPollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      context.read<CatalogCubit>().loadFlashSales();
    });
  }

  @override
  void dispose() {
    _flashPollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: BlocSelector<AuthCubit, AuthState, String?>(
          selector: (state) {
            final fullName = state.profile?.fullName.trim() ?? '';
            if (fullName.isEmpty) return null;
            return fullName.split(RegExp(r'\s+')).first;
          },
          builder: (context, firstName) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                homeGreeting(l, firstName, (widget.clock ?? DateTime.now)()),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.onSurface.withValues(alpha: .6)),
              ),
              Text(
                l.brandName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: scheme.primary, letterSpacing: 1.15),
              ),
            ],
          ),
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
          // Flash sale binding (T1): server-driven. First active sale drives
          // countdown (state.flashRemaining via loadFlashSales → startFlashSale)
          // and discount label. Product resolved by product_id lookup with
          // visible.first fallback to keep hero populated even before sales load.
          final flashSale = state.flashSales.firstOrNull;
          final flashProduct = flashSale == null
              ? (state.visible.isEmpty ? null : state.visible.first)
              : state.allProducts
                      .where((p) => p.id == flashSale['product_id'])
                      .firstOrNull ??
                  (state.visible.isEmpty ? null : state.visible.first);
          final discountLabel = flashSale == null
              ? '-15%'
              : '-${flashSale['discount_pct'] ?? flashSale['discountPct'] ?? 15}%';
          // Wishlist drives heart icons — wrap CustomScrollView so SliverGrid stays lazy and reactive.
          // ResponsiveShell caps width at 1200px on tablet/desktop.
          return BlocBuilder<WishlistCubit, WishlistState>(
            builder: (context, wishlist) {
              return ResponsiveShell(
                child: CustomScrollView(
                  // Dismiss the search keyboard on scroll: an open IME
                  // shrank the viewport into a 7.6px bottom overflow
                  // (live-found 2026-09-04).
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.all(16),
                      sliver: SliverList.list(
                        children: [
                          StitchSearchBar(
                            controller: _searchController,
                            onChanged: catalog.updateQuery,
                            // Outer SliverPadding already gutters 16 — keep
                            // vertical rhythm only to avoid a 32px double inset.
                            padding: const EdgeInsetsDirectional.symmetric(
                                vertical: 8),
                          ),
                          if (state.filters.query.isEmpty &&
                              state.recentQueries.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final q in state.recentQueries)
                                  Chip(
                                    label: Text(q),
                                    avatar: const Icon(Icons.history, size: 16),
                                    onDeleted: () =>
                                        catalog.deleteRecentQuery(q),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 14),
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
                            selected: state.filters.category,
                            onSelect: catalog.select,
                            categories: state.categories,
                          ),
                        ],
                      ),
                    ),
                    if (flashProduct != null) ...[
                      SliverPadding(
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(l.flashSale,
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                              ),
                              Text(
                                discountLabel,
                                style: TextStyle(
                                  color: scheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsetsDirectional.all(16),
                        sliver: SliverToBoxAdapter(
                          child: StitchFlashSaleCard(
                            product: flashProduct,
                            discountLabel: discountLabel,
                            onAdd: () =>
                                context.read<CartCubit>().add(flashProduct),
                            onTap: () =>
                                context.push('/product/${flashProduct.id}'),
                          ),
                        ),
                      ),
                    ],
                    SliverPadding(
                      padding:
                          const EdgeInsetsDirectional.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(l.popularProducts,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                            ),
                            PopupMenuButton<CatalogSort>(
                              tooltip: l.sortProducts,
                              initialValue: state.filters.sort,
                              onSelected: catalog.selectSort,
                              itemBuilder: (_) => CatalogSort.values
                                  .map((sort) => PopupMenuItem(
                                      value: sort, child: Text(sort.label)))
                                  .toList(),
                              child: Chip(
                                avatar: const Icon(Icons.sort, size: 18),
                                label: Text(state.filters.sort.label),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
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
                              return StitchProductGridCard(
                                product: product,
                                onTap: () =>
                                    context.push('/product/${product.id}'),
                                onWishlist: () => context
                                    .read<WishlistCubit>()
                                    .toggle(product.id),
                                isWishlisted: wishlist.ids.contains(product.id),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Time-of-day greeting copy (UX-044).
///
/// Buckets: 05:00–11:59 morning, 12:00–16:59 afternoon, otherwise evening
/// (17:00–04:59). [firstName] selects the personalized form; `null` picks
/// the guest form.
String homeGreeting(AppLocalizations l10n, String? firstName, DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return firstName == null
        ? l10n.goodMorningGuest
        : l10n.goodMorning(firstName);
  }
  if (hour >= 12 && hour < 17) {
    return firstName == null
        ? l10n.goodAfternoonGuest
        : l10n.goodAfternoon(firstName);
  }
  return firstName == null
      ? l10n.goodEveningGuest
      : l10n.goodEvening(firstName);
}
