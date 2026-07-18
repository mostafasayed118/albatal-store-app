import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/active_filters_bar.dart';
import '../widgets/catalog_empty_state.dart';
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
              _SearchBar(controller: _searchController),
              if (state.hasActiveFilters)
                ActiveFiltersBar(
                  state: state,
                  onClearAll: () {
                    _searchController.clear();
                    catalog.clearFilters();
                  },
                ),
              _SortBar(state: state),
              Expanded(
                child: state.visible.isEmpty
                    ? CatalogEmptyState(
                        onClear: () {
                          _searchController.clear();
                          catalog.clearFilters();
                        },
                      )
                    : _ProductGrid(products: state.visible),
              ),
            ],
          );
        },
      ),
    );
  }

  int _activeFilterCount(CatalogState state) {
    var count = 0;
    if (state.category != 'All') count++;
    if (state.colorFilter.isNotEmpty) count++;
    if (state.priceMin > 0 || state.priceMax < 999999) count++;
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: controller,
        onChanged: catalog.updateQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l.searchFabrics,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  tooltip: l.clearSearch,
                  onPressed: () {
                    controller.clear();
                    catalog.updateQuery('');
                  },
                  icon: const Icon(Icons.close),
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(l.fabricsFound(state.visible.length),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          PopupMenuButton<CatalogSort>(
            tooltip: l.sortProducts,
            initialValue: state.sort,
            onSelected: catalog.selectSort,
            itemBuilder: (_) => CatalogSort.values
                .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                .toList(),
            child: Chip(
              avatar: const Icon(Icons.sort, size: 18),
              label: Text(state.sort.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});
  final List products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => ProductTile(products[i]),
    );
  }
}
