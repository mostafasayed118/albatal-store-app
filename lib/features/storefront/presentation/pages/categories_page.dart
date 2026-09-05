import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/components/stitch/stitch_category_chips.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/catalog_cubit.dart';
import '../widgets/color_swatches.dart';
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
          final cats = visibleCategoryChips(state.categories);
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
                  itemBuilder: (_, i) =>
                      _CategoryCard(category: cats[i], onTap: openCategory),
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
  const _CategoryCard({required this.category, required this.onTap});
  final String category;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = categoryAccent(category);
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
                  Center(
                    child: Icon(Icons.texture, color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tactile mid-tone tint per fabric family, with a deterministic hue
/// fallback for categories the catalog grows later.
Color categoryAccent(String category) {
  const accents = <String, Color>{
    'Silk': Color(0xFFB08A2E),
    'Cotton': Color(0xFF7D8B6A),
    'Velvet': Color(0xFF6E1423),
    'Linen': Color(0xFFA9824F),
    'Wool': Color(0xFF4A5058),
    'Chiffon': Color(0xFF8A7FA8),
    'Satin': Color(0xFF8C5A6A),
    'Denim': Color(0xFF2F5A8C),
  };
  return accents[category] ?? deterministicTint(category);
}

/// Categories shown as chips/grid: drops a leading 'All' selector when the
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
