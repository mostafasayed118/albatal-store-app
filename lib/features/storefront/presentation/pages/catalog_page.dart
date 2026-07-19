import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/active_filters_bar.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/catalog_search_bar.dart';
import '../widgets/catalog_sort_bar.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/product_tile.dart';

/// Full catalog page with search bar, sort, and filter bottom sheet.
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
        context.read<CatalogCubit>().updateQuery(widget.initialQuery!);
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
              CatalogSearchBar(controller: _searchController),
              if (state.hasActiveFilters)
                ActiveFiltersBar(
                  state: state,
                  onClearAll: () {
                    _searchController.clear();
                    catalog.clearFilters();
                  },
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.visible.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: .68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (_, i) => ProductTile(state.visible[i]),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
