import 'package:flutter/material.dart';

/// Carousel index dot — extracted from `stitch_hero_carousel.dart`
/// verbatim (was private `_Dot`).
///
/// 6dp dot, stretched into a 16dp pill when [active], white-on-scrim for
/// legibility over both image and gradient slides.
class HeroDot extends StatelessWidget {
  const HeroDot({required this.active, super.key});

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
