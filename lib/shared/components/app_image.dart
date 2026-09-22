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
    this.cacheWidth,
    this.cacheHeight,
  });

  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final ColorFilter? colorFilter;
  final String? semanticsLabel;
  final int? cacheWidth;
  final int? cacheHeight;

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

    // HTTPS-only (audit P5): a cleartext `http://` image URL never
    // reaches the network stack — it renders the fallback instead, so a
    // misconfigured CMS row or a downgrade cannot pull pixels over
    // cleartext. All Supabase storage URLs are https.
    if (path.startsWith('https://')) {
      // Default downsampling (audit): explicit cacheWidth/cacheHeight win;
      // otherwise decode at the layout size * devicePixelRatio, capped at
      // 1080px, so callers that size the widget never decode full-res.
      // Aspect-scoped dependency (audit 2026-09-21): the old
      // MediaQuery.maybeOf rebuilt every AppImage on each IME/view-inset
      // animation frame; devicePixelRatioOf depends on the DPR aspect only.
      // Callers that pass BOTH cache bounds take no MediaQuery dependency
      // at all — only the default-sizing path needs a DPR.
      final needsDefault = cacheWidth == null || cacheHeight == null;
      final dpr = needsDefault
          ? (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0)
          : 1.0;
      int? defaultFor(double? extent) =>
          extent == null ? null : (extent * dpr).round().clamp(1, 1080);
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth ?? defaultFor(width),
        memCacheHeight: cacheHeight ?? defaultFor(height),
        placeholder: (_, __) => _fallback(context),
        errorWidget: (_, __, ___) => _fallback(context),
      );
    }

    if (path.startsWith('http://')) {
      assert(false, 'Cleartext image URL rejected (use https): $path');
      return _fallback(context);
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
