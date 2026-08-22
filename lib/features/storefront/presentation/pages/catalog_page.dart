import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/components/stitch/stitch_product_grid_card.dart';
import '../../../../shared/components/stitch/stitch_search_bar.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/wishlist_cubit.dart';
import '../widgets/active_filters_bar.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/catalog_sort_bar.dart';
import '../widgets/filter_sheet.dart';

/// Full catalog page with Stitch pill search + 2-col .68 grid via [productGridDelegate].
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<CatalogCubit>().updateQuery(widget.initialQuery!);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.categories),
        actions: [
          BlocBuilder<CatalogCubit, CatalogState>(
            builder: (context, state) {
              final activeCount = _activeFilterCount(state);
              return IconButton(
                tooltip: l.filters,
                onPressed: () => _showFilterSheet(context, state),
                icon: activeCount > 0
                    ? Badge(
                        label: Text('$activeCount',
                            style: const TextStyle(fontSize: 10)),
                        child: const Icon(Icons.tune),
                      )
                    : const Icon(Icons.tune),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, state) {
          final catalog = context.read<CatalogCubit>();
          return Column(
            children: [
              StitchSearchBar(
                controller: _searchController,
                hintText: l.searchFabrics,
                onChanged: catalog.updateQuery,
                onSubmitted: catalog.updateQuery,
              ),
              if (state.hasActiveFilters)
                ActiveFiltersBar(
                  state: state,
                  onClearAll: () {
                    _searchController.clear();
                    catalog.clearFilters();
                  },
                ),
              // Stitch circular chips (secondary filter row) — mirrors Home but
              // wired to the same CatalogCubit so chip taps filter the visible grid.
              if (state.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4, bottom: 4),
                  child: StitchCategoryChips(
                    selected: state.category,
                    categories: state.categories,
                    onSelect: catalog.select,
                  ),
                ),
              CatalogSortBar(state: state),
              Expanded(
                child: state.visible.isEmpty
                    ? CatalogEmptyState(
                        onClear: () {
                          _searchController.clear();
                          catalog.clearFilters();
                        },
                      )
                    : BlocBuilder<WishlistCubit, WishlistState>(
                        builder: (context, wishlist) => GridView.builder(
                          padding: const EdgeInsetsDirectional.all(16),
                          itemCount: state.visible.length,
                          gridDelegate: productGridDelegate,
                          itemBuilder: (_, i) {
                            final product = state.visible[i];
                            return StitchProductGridCard(
                              product: product,
                              onTap: () {
                                final router = GoRouter.maybeOf(context);
                                if (router != null) {
                                  context.push('/product/${product.id}');
                                }
                              },
                              onWishlist: () => context
                                  .read<WishlistCubit>()
                                  .toggle(product.id),
                              isWishlisted:
                                  wishlist.ids.contains(product.id),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _activeFilterCount(CatalogState state) {
    var count = 0;
    if (state.category != 'All') {
      count++;
    }
    if (state.colorFilter.isNotEmpty) {
      count++;
    }
    if (state.priceMin > Money.zero ||
        state.priceMax < const Money.egp(999999)) {
      count++;
    }
    return count;
  }

  void _showFilterSheet(BuildContext context, CatalogState state) {
    final catalog = context.read<CatalogCubit>();
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      builder: (_) => FilterSheet(
        state: state,
        onApply: (category, color, priceMin, priceMax) {
          if (category != state.category) catalog.select(category);
          catalog.setColorFilter(color);
          catalog.setPriceRange(priceMin, priceMax);
        },
      ),
    );
  }
}
