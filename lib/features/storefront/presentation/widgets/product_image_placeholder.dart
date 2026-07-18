import 'package:flutter/material.dart';

import 'fabric_weave_painter.dart';

/// Fabric swatch stand-in for product imagery.
///
/// When [imageAsset] is non-null, renders the supplied product photo via
/// `Image.asset` over a faint [imageColor] halo so the tactile identity of
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
  });

  final int imageColor;
  final String? imageAsset;
  final double size;
  final BoxConstraints? constraints;

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
          ? CustomPaint(
              painter: FabricWeavePainter(baseColor: Color(imageColor)),
              size: Size.infinite,
              child: Center(
                child: Icon(Icons.texture, color: Colors.white, size: size),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Color(imageColor)),
                Image.asset(
                  imageAsset!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ],
            ),
    );
    return constraints != null ? container : Expanded(child: container);
  }
}
