import 'package:flutter/material.dart';

import '../../../core/entities/product.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../extensions/build_context_x.dart';
import '../../l10n/money_copy.dart';
import '../../theme/app_colors.dart';
import 'hero/hero_dot.dart';
import 'hero/hero_slide_card.dart';

/// One slide of [StitchHeroCarousel].
///
/// Two visual kinds share this shape:
/// - **Promo slide** (`imageAsset == null`): the mockup hero's primary
///   gradient background with "New Arrival / New Silk Collection / 20% Off"
///   copy and the gold-gradient Shop Now pill.
/// - **Product slide**: a featured product's image (swatch-backed
///   [AppImage]) under a scrim, with the product's category, name, and
///   price. Tapping lands on the product details page.
///
/// [imageAsset] accepts a local asset path or a remote URL — [AppImage]
/// resolves both, and [swatchColor] keeps the fabric identity visible
/// during load-in (same contract as the grid/flash cards).
class StitchHeroSlide {
  const StitchHeroSlide({
    this.imageAsset,
    this.swatchColor = AppColors.primary,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onTap,
  });

  /// Local asset or remote URL; `null` renders the mockup's primary
  /// gradient promo background instead of an image.
  final String? imageAsset;
  final Color swatchColor;
  final String eyebrow;
  final String title;
  final String? subtitle;

  /// Pill CTA label. When null, the whole slide is the tap target.
  final String? ctaLabel;
  final VoidCallback? onTap;

  /// Builds the promo slide exactly as the Splash/Onboarding/Home mockup:
  /// "New Arrival" eyebrow, "New Silk Collection" headline, "20% Off", and
  /// the gold-gradient "Shop Now" pill routing to /categories.
  factory StitchHeroSlide.promo({
    required String eyebrow,
    required String title,
    required String subtitle,
    required String ctaLabel,
    VoidCallback? onTap,
  }) =>
      StitchHeroSlide(
        imageAsset: null,
        eyebrow: eyebrow,
        title: title,
        subtitle: subtitle,
        ctaLabel: ctaLabel,
        onTap: onTap,
      );

  /// Builds a product slide from a [Product] (category eyebrow, name,
  /// formatted price, swatch-backed image, tap → details).
  ///
  /// The hero is the largest surface in the app (full-bleed at an 840px
  /// decode budget), so it takes the DETAIL render from [Product.images]
  /// rather than the grid-width budget [Product.imageAsset] carries. Local
  /// products (asset paths, no image list) keep using their primary asset.
  ///
  /// [l10n] is required rather than optional: the subtitle is shopper
  /// copy, so it must render in the reader's locale (audit UX-019). A
  /// context-free factory cannot reach [Localizations], so the caller
  /// hands its own in — silently falling back to the Latin formatter
  /// would reintroduce the defect on the app's most prominent price.
  factory StitchHeroSlide.fromProduct(Product product,
          {required AppLocalizations l10n, VoidCallback? onTap}) =>
      StitchHeroSlide(
        imageAsset: product.images.isNotEmpty
            ? product.images.first
            : product.imageAsset,
        swatchColor: Color(product.imageColor),
        eyebrow: product.category,
        title: product.name,
        subtitle: moneyText(l10n, product.price),
        onTap: onTap,
      );
}

/// Stitch multi-slide hero — the spec §4 StitchHeroCarousel contract.
///
/// A 180dp (16dp-radius) [PageView] whose slides carry the mockup hero's
/// exact content treatment (primary gradient or image + scrim, eyebrow /
/// headline / offer copy, gold-gradient pill CTA), plus **index dots** —
/// the one element the single-card mockup could not show. Dots render
/// bottom-end (directional, so they mirror in RTL) as 6dp dots with the
/// active one stretched into a 16dp pill, white-on-scrim for legibility
/// over both image and gradient slides.
///
/// Swipe or tap the dots to change slides; [onPageChanged] reports the
/// index for callers that want to mirror it elsewhere (e.g. a state
/// field). RepaintBoundary-wrapped for scroll cheapness like the other
/// stitch primitives.
class StitchHeroCarousel extends StatefulWidget {
  const StitchHeroCarousel({
    super.key,
    required this.slides,
    this.height = 180,
    this.onPageChanged,
  });

  final List<StitchHeroSlide> slides;
  final double height;
  final ValueChanged<int>? onPageChanged;

  @override
  State<StitchHeroCarousel> createState() => _StitchHeroCarouselState();
}

class _StitchHeroCarouselState extends State<StitchHeroCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => HeroSlideCard(slide: widget.slides[i]),
            ),
            // Index dots — bottom-end, directional (mirrors in RTL), and
            // clear of the bottom-start CTA pill. A single slide needs no
            // navigation affordance, so dots render for 2+ slides only.
            if (widget.slides.length > 1)
              PositionedDirectional(
                bottom: 12,
                end: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.slides.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      // Dots are anonymous 6dp shapes visually — give the
                      // screen reader a button with a localized "go to
                      // slide N" name and the selected state. (The
                      // GestureDetector's own tap action is inherited;
                      // no duplicate onTap here.)
                      Semantics(
                        button: true,
                        selected: i == _index,
                        label: context.l10n.goToSlide(i + 1),
                        child: GestureDetector(
                          // Dots are a real affordance: tap jumps to the slide.
                          onTap: () => _controller.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: HeroDot(
                              active: i == _index,
                              key: ValueKey('stitch_hero_dot_$i'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
