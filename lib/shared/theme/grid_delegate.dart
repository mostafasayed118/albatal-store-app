import 'package:flutter/material.dart';

/// Width-aware product grid used by the storefront catalog surfaces.
///
/// The grid keeps two columns on phones, adds a third column at tablet width,
/// and caps card width on large screens so product imagery stays legible.
SliverGridDelegate productGridDelegateForWidth(double width) {
  final crossAxisCount = width >= 1000
      ? 4
      : width >= 700
          ? 3
          : 2;
  final horizontalGap = width >= 700 ? 16.0 : 12.0;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    childAspectRatio: width < 360 ? .62 : .68,
    crossAxisSpacing: horizontalGap,
    mainAxisSpacing: 12,
  );
}

/// Backwards-compatible phone default for existing callers and tests.
const productGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  childAspectRatio: .68,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
);
