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
          final cats = state.categories.length > 1
              ? state.categories.sublist(1)
              : const <String>['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];
          // Stitch circular 56dp horizontal chips — reuses shared primitive.
          // EdgeInsetsDirectional inside StitchCategoryChips ensures RTL mirroring;
          // InkSparkle via AppTheme splashFactory.
          return ListView(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            children: [
              StitchCategoryChips(
                selected: state.filters.category,
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
