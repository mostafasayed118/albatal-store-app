import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../catalog_sort_label.dart';
import '../cubit/catalog_cubit.dart';

/// Sort dropdown and product count.
class CatalogSortBar extends StatelessWidget {
  const CatalogSortBar({super.key, required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l.fabricsFound(state.visible.length),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: PopupMenuButton<CatalogSort>(
              tooltip: l.sortProducts,
              initialValue: state.filters.sort,
              onSelected: catalog.selectSort,
              itemBuilder: (_) => CatalogSort.values
                  .map((s) => PopupMenuItem(
                      value: s, child: Text(catalogSortLabel(l, s))))
                  .toList(),
              child: Chip(
                avatar: const Icon(Icons.sort, size: 18),
                label: Text(
                  catalogSortLabel(l, state.filters.sort),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
