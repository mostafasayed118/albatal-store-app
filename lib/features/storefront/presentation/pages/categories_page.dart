import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.fabricCategories)),
      body: BlocBuilder<CatalogCubit, CatalogState>(
        builder: (context, state) {
          final catalog = context.read<CatalogCubit>();
          if (state.status == CatalogStatus.loading ||
              state.status == CatalogStatus.initial) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == CatalogStatus.error) {
            return FeedbackView(
              type: FeedbackViewType.error,
              onAction: catalog.load,
            );
          }
          final cats = visibleCategoryChips(state.categories);
          // Stitch circular 56dp horizontal chips — reuses shared primitive.
          // EdgeInsetsDirectional inside StitchCategoryChips ensures RTL mirroring;
          // InkSparkle via AppTheme splashFactory.
          return ListView(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            children: [
              StitchCategoryChips(
                selected: state.category,
                categories: cats,
                onSelect: (cat) {
                  catalog.select(cat);
                  final router = GoRouter.maybeOf(context);
                  if (router != null) {
                    context.go('/catalog');
                  }
                },
              ),
              // Optional helper text under chips for a11y; keeps layout Stitch-faithful
              // without reintroducing the legacy CategoryGrid gradients.
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

/// Categories shown as chips: drops a leading 'All' selector when the
/// catalog provides one, keeps everything otherwise.
///
/// A blind `sublist(1)` dropped the Wool category on devices where the
/// loaded list has no 'All' first entry (live-found 2026-09-04).
List<String> visibleCategoryChips(List<String> categories) {
  const defaults = <String>['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];
  if (categories.isEmpty) return defaults;
  final chips = categories.first == 'All' ? categories.sublist(1) : categories;
  return chips.isEmpty ? defaults : chips;
}
