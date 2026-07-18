import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';

/// Search bar for catalog page.
class CatalogSearchBar extends StatelessWidget {
  const CatalogSearchBar({super.key, required this.controller});
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
