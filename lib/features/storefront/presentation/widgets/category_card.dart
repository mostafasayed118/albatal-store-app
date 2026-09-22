import 'package:flutter/material.dart';

import '../../../../shared/components/app_card.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../catalog_constants.dart';
import 'fabric_weave_painter.dart';

/// A tactile category card: weave-tinted tile + label, sharing the
/// product-grid proportions so the page reads as one visual system.
///
/// Extracted from `categories_page.dart` (was private `_CategoryCard`).
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
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
    return AppCard(
      clipBehavior: Clip.antiAlias,
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
