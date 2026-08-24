import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders app-owned images as SVG and remote catalog images as cached URLs.
///
/// Local runtime image sources must use `.svg`; raster files are reserved for
/// platform packaging and historical evidence outside `assets/images/`.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholder,
    this.colorFilter,
    this.semanticsLabel,
  });

  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final ColorFilter? colorFilter;
  final String? semanticsLabel;

  Widget _fallback(BuildContext context) {
    return placeholder ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Icon(
            Icons.texture,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final path = source;
    if (path == null || path.isEmpty) return _fallback(context);

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => _fallback(context),
        errorWidget: (_, __, ___) => _fallback(context),
      );
    }

    if (!path.toLowerCase().endsWith('.svg')) {
      assert(
        false,
        'Local runtime image assets must be SVG: $path',
      );
      return _fallback(context);
    }
    return SvgPicture.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      colorFilter: colorFilter,
      semanticsLabel: semanticsLabel,
      placeholderBuilder: (_) => _fallback(context),
    );
  }
}
