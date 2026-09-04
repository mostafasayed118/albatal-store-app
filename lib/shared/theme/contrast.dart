import 'package:flutter/material.dart';

/// Returns a legible icon color for content drawn over [background].
///
/// Fabric swatches span cream to charcoal, so a fixed white glyph vanishes
/// on light stock. Dark ink above the 0.45 luminance midpoint keeps contrast
/// above ~4.5:1 on both ends without per-product tuning.
Color onSwatchColor(Color background) {
  return background.computeLuminance() > 0.45
      ? const Color(0xFF1A1C1C)
      : Colors.white;
}
