import 'package:flutter/material.dart';

import '../../../../shared/components/app_image.dart';
import '../../../../shared/theme/contrast.dart';
import 'fabric_weave_painter.dart';

/// Fabric swatch stand-in for product imagery.
///
/// When [imageAsset] is non-null, renders the supplied local SVG or remote
/// product photo over a faint [imageColor] halo so the tactile identity of
/// the swatch is preserved during image load-in. When [imageAsset] is null
/// (e.g. an older serialized order snapshot), falls back to the woven
/// [FabricWeavePainter] over [imageColor] — preserving visual continuity
/// with the original DESIGN.md language.
///
/// Per DESIGN.md the swatch floats on a faint primary-tinted halo
/// (Level 1 elevation) rather than a hard drop shadow.
class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder({
    super.key,
    required this.imageColor,
    this.imageAsset,
    this.size = 42,
    this.constraints,
    this.cacheExtent,
  });

  final int imageColor;
  final String? imageAsset;
  final double size;
  final BoxConstraints? constraints;

  /// Decode-size bound forwarded as both `cacheWidth`/`cacheHeight` to the
  /// inner [AppImage]. Defaults to the 720px card budget; tiny slots
  /// (e.g. the 72px cart thumb) pass ~2x their footprint so a thumbnail
  /// never decodes a full-resolution bitmap.
  final int? cacheExtent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final container = Container(
      constraints: constraints,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? .12 : .035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageAsset == null
          // Isolated repaint: the weave repaints only when its own
          // color changes, never with an ancestor scroll. isComplex
          // stays false — the hatch is a handful of lines.
          ? RepaintBoundary(
              child: CustomPaint(
                isComplex: false,
                painter: FabricWeavePainter(baseColor: Color(imageColor)),
                size: Size.infinite,
                child: Center(
                  child: Icon(Icons.texture,
                      color: onSwatchColor(Color(imageColor)), size: size),
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Color(imageColor)),
                AppImage(
                  source: imageAsset,
                  fit: BoxFit.cover,
                  cacheWidth: cacheExtent ?? 720,
                  cacheHeight: cacheExtent ?? 720,
                  placeholder: Icon(Icons.texture,
                      color: onSwatchColor(Color(imageColor)), size: size),
                ),
              ],
            ),
    );
    return constraints != null ? container : Expanded(child: container);
  }
}
