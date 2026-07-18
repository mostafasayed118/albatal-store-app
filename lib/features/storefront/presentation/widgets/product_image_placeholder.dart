import 'package:flutter/material.dart';

/// Fabric swatch placeholder standing in for product photography.
///
/// Per DESIGN.md the swatch floats on a faint primary-tinted halo
/// (Level 1 elevation) rather than a hard drop shadow, and respects
/// the rounded card radius token.
class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder({
    super.key,
    required this.imageColor,
    this.size = 42,
    this.constraints,
  });

  final int imageColor;
  final double size;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final container = Container(
      constraints: constraints,
      decoration: BoxDecoration(
        color: Color(imageColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? .12 : .035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.texture, color: Colors.white, size: size),
      ),
    );
    return constraints != null ? container : Expanded(child: container);
  }
}
