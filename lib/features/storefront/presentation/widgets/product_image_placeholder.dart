import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'fabric_weave_painter.dart';

/// Whether an image path is a remote URL (http/https) or a local asset.
bool _isRemoteUrl(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Fabric swatch stand-in for product imagery.
///
/// Supports three rendering modes:
/// 1. **Remote URL** — uses [CachedNetworkImage] with disk caching and
///    placeholder/error fallbacks. Falls back to [imageColor] on load error.
/// 2. **Local asset** — uses [Image.asset] with [gaplessPlayback] for
///    smooth transitions.
/// 3. **Null** — renders the woven [FabricWeavePainter] over [imageColor].
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
      child: _buildContent(),
    );
    return constraints != null ? container : Expanded(child: container);
  }

  Widget _buildContent() {
    if (imageAsset == null) {
      return CustomPaint(
        painter: FabricWeavePainter(baseColor: Color(imageColor)),
        size: Size.infinite,
        child: Center(
          child: Icon(Icons.texture, color: Colors.white, size: size),
        ),
      );
    }

    if (_isRemoteUrl(imageAsset!)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Color(imageColor)),
          CachedNetworkImage(
            imageUrl: imageAsset!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Center(
              child: Icon(Icons.texture, color: Colors.white, size: size),
            ),
            errorWidget: (_, __, ___) => Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: size),
            ),
          ),
        ],
      );
    }

    // Local asset
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(imageColor)),
        Image.asset(
          imageAsset!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ],
    );
  }
}
