import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';

/// Search bar with voice/clear suffix icons.
///
/// Tapping search or submitting navigates to the full [/catalog] page
/// with the query pre-filled. The controller lives in the parent [HomePage].
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
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) {
          context.go('/catalog?q=${Uri.encodeComponent(value.trim())}');
        } else {
          context.go('/catalog');
        }
      },
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
                  context.read<CatalogCubit>().updateQuery('');
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
