import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';

/// Search bar with voice/clear suffix icons.
///
/// The controller lives in the parent [HomePage] because it owns the
/// text editing lifecycle (clear on filter reset). The cubit receives
/// query updates via [CatalogCubit.updateQuery].
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.state,
  });

  final TextEditingController controller;
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = context.read<CatalogCubit>();
    return TextField(
      controller: controller,
      onChanged: catalog.updateQuery,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l.searchFabrics,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: state.query.isEmpty
            ? IconButton(
                tooltip: l.voiceSearch,
                onPressed: () {},
                icon: const Icon(Icons.mic),
              )
            : IconButton(
                tooltip: l.clearSearch,
                onPressed: () {
                  controller.clear();
                  catalog.updateQuery('');
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
      ),
    );
  }
}
