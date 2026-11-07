import 'package:flutter/material.dart';

/// Width-aware product grid used by the storefront catalog surfaces.
///
/// The grid keeps two columns on phones, adds a third column at tablet width,
/// and caps card width on large screens so product imagery stays legible.
///
/// [textScale] grows the cell height with the user's font size so fixed-height
/// tiles keep their media slot instead of clipping the text block. Surfaces
/// whose cards already flex their media (Stitch card) can leave it at 1.
SliverGridDelegate productGridDelegateForWidth(
  double width, {
  double textScale = 1,
  double baseAspectRatio = .68,
}) {
  final crossAxisCount = width >= 1000
      ? 4
      : width >= 700
          ? 3
          : 2;
  final horizontalGap = width >= 700 ? 16.0 : 12.0;
  // Narrow phones keep the taller legacy cell; everything else scales from
  // the caller's base ratio.
  final base = width < 360 ? baseAspectRatio - .06 : baseAspectRatio;
  final aspectRatio = (base / (1 + (textScale - 1) * 1.15)).clamp(.40, base);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    childAspectRatio: aspectRatio,
    crossAxisSpacing: horizontalGap,
    mainAxisSpacing: 12,
  );
}
