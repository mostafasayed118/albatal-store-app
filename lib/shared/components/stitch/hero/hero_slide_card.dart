import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../app_image.dart';
import '../stitch_hero_carousel.dart';
import 'gold_pill.dart';

/// One rendered hero slide card — extracted from
/// `stitch_hero_carousel.dart` verbatim (was private `_HeroSlideCard`).
///
/// Full-bleed 16dp-radius card: mockup primary gradient (promo) or the
/// product image over its swatch color, directional scrim for legibility,
/// and bottom-start content (eyebrow / headline / offer / [GoldPill] CTA).
class HeroSlideCard extends StatelessWidget {
  const HeroSlideCard({super.key, required this.slide});

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
                      GoldPill(label: slide.ctaLabel!, onTap: slide.onTap),
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
