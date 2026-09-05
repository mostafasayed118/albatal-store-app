import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Single pipeline for rendering a product image.
///
/// The null → texture-icon / http → `CachedNetworkImage` / asset →
/// `Image.asset` decision chain used to be copy-pasted between
/// `stitch_product_grid_card.dart` and `stitch_flash_sale_card.dart`,
/// and other widgets (gallery, zoom, category grid) rendered
/// `Image.asset` without any error fallback — which crashes on a
/// network URL in release builds. Every product image now goes through
/// this resolver so the rules (and the failure fallback) live in one
/// place.
///
/// All branches paint over a color block of [imageColor] with the
/// texture fallback icon, preserving the swatch identity from
/// DESIGN.md while images load or when they are missing.
class ProductImageResolver extends StatelessWidget {
  const ProductImageResolver({
    super.key,
    required this.imageColor,
    required this.asset,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
    this.gaplessPlayback = true,
  });

  final int imageColor;

  /// Asset path or http(s) URL; `null` or empty renders the fallback.
  final String? asset;
  final BoxFit fit;

  /// Size of the texture fallback icon (match the call site's original).
  final double iconSize;

  /// Keep the old image visible while the asset path changes.
  final bool gaplessPlayback;

  Widget _fallback() => ColoredBox(
        color: Color(imageColor),
        child: Center(
          child: Icon(Icons.texture, color: Colors.white, size: iconSize),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = asset;
    if (url == null || url.isEmpty) return _fallback();
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (context, url) => _fallback(),
        errorWidget: (context, url, error) => _fallback(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Color underlay keeps the swatch visible while the asset loads.
        ColoredBox(color: Color(imageColor)),
        Image.asset(
          url,
          fit: fit,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      ],
    );
  }
}
