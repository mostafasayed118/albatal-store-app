import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
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
