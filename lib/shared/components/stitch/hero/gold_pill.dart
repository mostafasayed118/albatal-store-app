import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Mockup-exact CTA pill: 135° gold gradient (#B8860B → #FFFAF0 →
/// #B8860B) with primary-container text — the same stops as the mockup's
/// `linear-gradient(135deg, …)` and PromoBanner's original pill.
///
/// Extracted from `stitch_hero_carousel.dart` verbatim (was private
/// `_GoldPill`); public so other Stitch surfaces can reuse the exact pill.
class GoldPill extends StatelessWidget {
  const GoldPill({super.key, required this.label, this.onTap});

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
