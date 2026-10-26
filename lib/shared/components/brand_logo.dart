import 'package:flutter/material.dart';

enum BrandLogoVariant { lockup, mark }

enum BrandLogoTone { onDark, onLight }

/// Brand logo raster asset. Tone defaults to the active theme brightness:
/// dark theme -> onDark (white/gold), light theme -> onLight (emerald/gold).
/// Pass [tone] explicitly on surfaces with a fixed background (e.g. the
/// always-emerald splash).
final class BrandLogo extends StatelessWidget {
  const BrandLogo.lockup(
      {super.key, this.height = 96, this.tone, this.semanticsLabel})
      : variant = BrandLogoVariant.lockup;
  const BrandLogo.mark(
      {super.key, this.height = 40, this.tone, this.semanticsLabel})
      : variant = BrandLogoVariant.mark;

  final double height;
  final BrandLogoVariant variant;
  final BrandLogoTone? tone;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = tone ??
        (Theme.of(context).brightness == Brightness.dark
            ? BrandLogoTone.onDark
            : BrandLogoTone.onLight);
    final asset = switch ((variant, resolved)) {
      (BrandLogoVariant.lockup, BrandLogoTone.onDark) =>
        'assets/brand/logo_lockup_on_dark.png',
      (BrandLogoVariant.lockup, BrandLogoTone.onLight) =>
        'assets/brand/logo_lockup_on_light.png',
      (BrandLogoVariant.mark, BrandLogoTone.onDark) =>
        'assets/brand/logo_mark_on_dark.png',
      (BrandLogoVariant.mark, BrandLogoTone.onLight) =>
        'assets/brand/logo_mark_on_light.png',
    };
    return Image.asset(
      asset,
      height: height,
      cacheHeight:
          (height * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0))
              .round()
              .clamp(1, 1200),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticsLabel,
      excludeFromSemantics: semanticsLabel == null,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.auto_awesome,
        size: height * .5,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
