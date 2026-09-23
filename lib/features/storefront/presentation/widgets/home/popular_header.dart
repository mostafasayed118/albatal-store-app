import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../catalog_sort_label.dart';
import '../../cubit/catalog_cubit.dart';

/// Popular-products header: title + the sort chip driven by
/// [CatalogCubit.selectSort].
///
/// Extracted from `home_page.dart` verbatim (was private `_PopularHeader`).
final class HomePopularHeader extends StatelessWidget {
  const HomePopularHeader({
    super.key,
    required this.title,
    required this.sort,
    required this.onSortSelected,
  });

  final String title;
  final CatalogSort sort;
  final ValueChanged<CatalogSort> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        PopupMenuButton<CatalogSort>(
          tooltip: l.sortProducts,
          initialValue: sort,
          onSelected: onSortSelected,
          itemBuilder: (_) => CatalogSort.values
              .map((s) => PopupMenuItem(
                  value: s, child: Text(catalogSortLabel(l, s))))
              .toList(),
          child: Chip(
            avatar: const Icon(Icons.sort, size: 18),
            label: Text(catalogSortLabel(l, sort)),
          ),
        ),
      ],
    );
  }
}
