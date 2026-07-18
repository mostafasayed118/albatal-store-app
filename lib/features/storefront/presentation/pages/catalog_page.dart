import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/catalog_cubit.dart';
import '../../data/products_data.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/product_tile.dart';

/// Full catalog page with search bar, sort, and filter bottom sheet.
///
/// This page reuses the global [CatalogCubit] so filters persist when
/// navigating to a product detail page and coming back.
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, this.initialQuery});

  /// Pre-fill the search bar when navigated to from the home page.
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
    final scheme = Theme.of(context).colorScheme;
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
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: catalog.updateQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.searchFabrics,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.query.isNotEmpty
                        ? IconButton(
                            tooltip: l.clearSearch,
                            onPressed: () {
                              _searchController.clear();
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
              ),

              // Active filter chips
              if (state.hasActiveFilters)
                _ActiveFiltersBar(
                  state: state,
                  onClearAll: () {
                    _searchController.clear();
                    catalog.clearFilters();
                  },
                ),

              // Sort bar + count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(l.fabricsFound(state.visible.length),
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    PopupMenuButton<CatalogSort>(
                      tooltip: l.sortProducts,
                      initialValue: state.sort,
                      onSelected: catalog.selectSort,
                      itemBuilder: (_) => CatalogSort.values
                          .map((s) => PopupMenuItem(
                              value: s, child: Text(s.label)))
                          .toList(),
                      child: Chip(
                        avatar: const Icon(Icons.sort, size: 18),
                        label: Text(state.sort.label),
                      ),
                    ),
                  ],
                ),
              ),

              // Product grid
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
                        gridDelegate: productGridDelegate,
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
      builder: (_) => _FilterSheet(
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

// ─── Active Filters Bar ─────────────────────────────────────────────

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    required this.state,
    required this.onClearAll,
  });

  final CatalogState state;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    final chips = <Widget>[];

    if (state.category != 'All') {
      chips.add(_filterChip(
        label: state.category,
        onDeleted: () => catalog.select('All'),
      ));
    }
    if (state.colorFilter.isNotEmpty) {
      chips.add(_filterChip(
        label: state.colorFilter,
        onDeleted: () => catalog.setColorFilter(state.colorFilter),
      ));
    }
    if (state.priceMin > 0 || state.priceMax < 999999) {
      chips.add(_filterChip(
        label: '${money(state.priceMin.toInt().toDouble())} – ${money(state.priceMax.toInt().toDouble())}',
        onDeleted: () => catalog.setPriceRange(0, 999999),
      ));
    }

    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          ...chips,
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: ActionChip(
                label: Text(l.clearAll),
                onPressed: onClearAll,
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required VoidCallback onDeleted}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─── Filter Bottom Sheet ────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.state,
    required this.onApply,
  });

  final CatalogState state;
  final void Function(String category, String color, double priceMin, double priceMax) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _selectedCategory;
  late String _selectedColor;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.state.category;
    _selectedColor = widget.state.colorFilter;
    final min = widget.state.catalogPriceMin;
    final max = widget.state.catalogPriceMax;
    _priceRange = RangeValues(
      widget.state.priceMin.clamp(min, max),
      widget.state.priceMax.clamp(min, max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final min = state.catalogPriceMin;
    final max = state.catalogPriceMax;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(l.filter, style: Theme.of(context).textTheme.titleLarge)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _selectedColor = '';
                      _priceRange = RangeValues(min, max);
                    });
                  },
                  child: Text(l.resetFilters),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category
            Text(l.category, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in state.categories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _selectedCategory == c,
                    onSelected: (_) => setState(() => _selectedCategory = c),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Color
            if (state.availableColors.isNotEmpty) ...[
              Text(l.color, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final color in state.availableColors)
                    ChoiceChip(
                      label: Text(color),
                      selected: _selectedColor == color,
                      onSelected: (_) => setState(() {
                        _selectedColor = _selectedColor == color ? '' : color;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Price range
            Text(l.priceRange, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RangeSlider(
              values: _priceRange,
              min: min,
              max: max,
              divisions: 20,
              labels: RangeLabels(
                money(_priceRange.start.round().toDouble()),
                money(_priceRange.end.round().toDouble()),
              ),
              onChanged: (v) => setState(() => _priceRange = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(money(_priceRange.start.round().toDouble()),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                Text(money(_priceRange.end.round().toDouble()),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            FilledButton(
              onPressed: () {
                widget.onApply(
                  _selectedCategory,
                  _selectedColor,
                  _priceRange.start,
                  _priceRange.end,
                );
                Navigator.pop(context);
              },
              child: Text(l.applyFilters),
            ),
          ],
        ),
      ),
    );
  }
}
