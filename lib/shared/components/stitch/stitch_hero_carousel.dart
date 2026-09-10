import 'package:flutter/material.dart';

import '../../../core/entities/product.dart';
import '../../theme/app_colors.dart';
import '../app_image.dart';

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
  factory StitchHeroSlide.fromProduct(Product product, {VoidCallback? onTap}) =>
      StitchHeroSlide(
        imageAsset: product.imageAsset,
        swatchColor: Color(product.imageColor),
        eyebrow: product.category,
        title: product.name,
        subtitle: product.price.format(),
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
              itemBuilder: (_, i) => _HeroSlideCard(slide: widget.slides[i]),
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
                      GestureDetector(
                        // Dots are a real affordance: tap jumps to the slide.
                        onTap: () => _controller.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _Dot(
                            active: i == _index,
                            key: ValueKey('stitch_hero_dot_$i'),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.95 : 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({required this.slide});

  final StitchHeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      // No horizontal padding: the mockup hero is full-bleed inside the
      // page gutter; vertical 0 keeps the 180dp contract exact.
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: slide.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: mockup primary gradient (promo) or the product
              // image over its swatch color.
              if (slide.imageAsset == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        scheme.primary.withValues(alpha: .75),
                      ],
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: slide.swatchColor,
                  child: AppImage(
                    source: slide.imageAsset,
                    fit: BoxFit.cover,
                    // Decode budget (audit P3): the 180dp hero slot does
                    // not need full-resolution source bitmaps — cap at
                    // ~2x dpr of the phone footprint (grid/flash cards
                    // follow the same pattern).
                    cacheWidth: 840,
                    cacheHeight: 360,
                    placeholder: Icon(
                      Icons.texture,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 32,
                    ),
                  ),
                ),
              // Scrim for text legibility over image slides (same
              // structural role as AppColors.scrim, but directional so it
              // darkens toward the reading edge).
              if (slide.imageAsset != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.bottomStart,
                      end: AlignmentDirectional.topEnd,
                      colors: [
                        AppColors.scrim,
                        AppColors.scrim.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              // Content — bottom-start, mockup hierarchy: eyebrow, headline,
              // offer line, gold-gradient pill CTA.
              PositionedDirectional(
                bottom: 16,
                start: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slide.eyebrow,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.secondaryContainer,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slide.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (slide.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        slide.subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.secondaryFixed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (slide.ctaLabel != null) ...[
                      const SizedBox(height: 10),
                      _GoldPill(label: slide.ctaLabel!, onTap: slide.onTap),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mockup-exact CTA pill: 135° gold gradient (#B8860B → #FFFAF0 →
/// #B8860B) with primary-container text — the same stops as the mockup's
/// `linear-gradient(135deg, …)` and PromoBanner's original pill.
class _GoldPill extends StatelessWidget {
  const _GoldPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            AppColors.goldDeep, // darkgoldenrod
            AppColors.goldPale, // floralwhite
            AppColors.goldDeep,
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryContainer,
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
