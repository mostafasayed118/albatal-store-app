import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../localization/category_labels.dart';

/// Horizontal scrollable category chips.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogCubit>();
    final l = context.l10n;
    final cats = state.categories.isNotEmpty
        ? state.categories
        : const ['All', 'Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cats
            .map((category) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(localizedCategory(category, l)),
                    selected: state.category == category,
                    onSelected: (_) => catalog.select(category),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
