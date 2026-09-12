import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../catalog_constants.dart';
import '../cubit/catalog_cubit.dart' hide CatalogConstants;
import '../widgets/fabric_weave_painter.dart';

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
              context.go('/catalog');
            }
          }

          // Stitch circular 56dp horizontal chips — reuses shared primitive.
          return ListView(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            children: [
              StitchCategoryChips(
                selected: state.filters.category,
                categories: cats,
                onSelect: openCategory,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                  gridDelegate:
                      productGridDelegateForWidth(constraints.maxWidth),
                  itemCount: cats.length,
                  itemBuilder: (_, i) => _CategoryCard(
                    category: cats[i],
                    // Product count per family, so the card tells the user
                    // how much there is to browse before they tap.
                    count: state.categoryProductCount[cats[i]] ?? 0,
                    onTap: openCategory,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A tactile category card: weave-tinted tile + label, sharing the
/// product-grid proportions so the page reads as one visual system.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });
  final String category;
  final int count;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = context.l10n;
    final tint = CatalogConstants.accentFor(category);
    return Card(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => onTap(category),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: FabricWeavePainter(baseColor: tint)),
                  // Soft scrim keeps the white glyph legible on any tint.
                  Container(color: Colors.black12),
                  const Center(
                    child: Icon(Icons.texture, color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.curatedFabrics(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Deprecated('Use CatalogConstants.accentFor instead.')
Color categoryAccent(String category) => CatalogConstants.accentFor(category);

@Deprecated('Use CatalogConstants.chipsFor instead.')
List<String> visibleCategoryChips(List<String> categories) =>
    CatalogConstants.chipsFor(categories);
