import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/catalog_cubit.dart';
import '../../data/products_data.dart';

/// Horizontal scrollable category chips.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogCubit>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map((category) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: state.category == category,
                    onSelected: (_) => catalog.select(category),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
