import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../catalog_constants.dart';
import '../cubit/catalog_cubit.dart' hide CatalogConstants;
import '../widgets/category_card.dart';

/// Fabric-category browsing.
///
/// Top row: the circular Stitch chips (quick switch, mirroring Home/Catalog).
/// Below: a real browse grid of tactile weave-tinted category cards so the
/// tab is a destination, not a chip dead-end. Each card filters the catalog
/// and jumps to it on tap.
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
          final cats = CatalogConstants.chipsFor(state.categories);
          void openCategory(String cat) {
            catalog.select(cat);
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              context.go(Routes.catalog);
            }
          }

          // Stitch circular 56dp horizontal chips — reuses shared primitive.
          return ListView.builder(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            itemCount: 3,
            itemBuilder: (context, i) => switch (i) {
              0 => StitchCategoryChips(
                  selected: state.filters.category,
                  categories: cats,
                  onSelect: openCategory,
                ),
              1 => const SizedBox(height: 12),
              _ => LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                    gridDelegate:
                        productGridDelegateForWidth(constraints.maxWidth),
                    itemCount: cats.length,
                    itemBuilder: (_, i) => CategoryCard(
                      category: cats[i],
                      // Product count per family, so the card tells the user
                      // how much there is to browse before they tap.
                      count: state.categoryProductCount[cats[i]] ?? 0,
                      onTap: openCategory,
                    ),
                  ),
                ),
            },
          );
        },
      ),
    );
  }
}

@Deprecated('Use CatalogConstants.accentFor instead.')
Color categoryAccent(String category) => CatalogConstants.accentFor(category);

@Deprecated('Use CatalogConstants.chipsFor instead.')
List<String> visibleCategoryChips(List<String> categories) =>
    CatalogConstants.chipsFor(categories);
