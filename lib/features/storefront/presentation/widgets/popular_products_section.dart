import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/product_tile.dart';

/// Popular products section with sort menu and product grid.
class PopularProductsSection extends StatelessWidget {
  const PopularProductsSection({
    super.key,
    required this.state,
    required this.onClearFilters,
  });

  final CatalogState state;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Text(l.popularProducts,
                    style: Theme.of(context).textTheme.titleLarge)),
            PopupMenuButton<CatalogSort>(
              tooltip: l.sortProducts,
              initialValue: state.sort,
              onSelected: catalog.selectSort,
              itemBuilder: (_) => CatalogSort.values
                  .map((sort) =>
                      PopupMenuItem(value: sort, child: Text(sort.labelFor(l))))
                  .toList(),
              child: Chip(
                avatar: const Icon(Icons.sort, size: 18),
                label: Text(state.sort.labelFor(l)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l.fabricsFound(state.visible.length)),
        const SizedBox(height: 12),
        if (state.visible.isEmpty)
          CatalogEmptyState(onClear: onClearFilters)
        else
          RepaintBoundary(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.visible.length,
              gridDelegate: productGridDelegate,
              itemBuilder: (_, index) => ProductTile(state.visible[index]),
            ),
          ),
      ],
    );
  }
}
