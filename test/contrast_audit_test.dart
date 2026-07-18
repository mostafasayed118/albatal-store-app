import 'dart:math' as math;

import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compute the WCAG 2.0 relative luminance of a color.
/// https://www.w3.org/TR/WCAG20/#relativeluminancedef
double _relativeLuminance(Color c) {
  double channel(double v) {
    v /= 255;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * channel(c.r * 255.0) +
      0.7152 * channel(c.g * 255.0) +
      0.0722 * channel(c.b * 255.0);
}

/// WCAG contrast ratio between two colors.
double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG contrast audit — light mode', () {
    final scheme = AppTheme.light().colorScheme;

    test('primary on surface meets AA (4.5:1)', () {
      expect(_contrastRatio(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('onPrimary on primary meets AA', () {
      expect(_contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5));
    });

    test('onSurface on surface meets AA', () {
      expect(_contrastRatio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('secondary on surface meets AA', () {
      expect(_contrastRatio(scheme.secondary, scheme.surface),
          greaterThanOrEqualTo(3.0)); // Large text threshold
    });

    test('error on surface meets AA', () {
      expect(_contrastRatio(scheme.error, scheme.surface),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('WCAG contrast audit — dark mode', () {
    final scheme = AppTheme.dark().colorScheme;

    test('primary on surface meets AA', () {
      expect(_contrastRatio(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('onPrimary on primary meets AA', () {
      expect(_contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5));
    });

    test('onSurface on surface meets AA', () {
      expect(_contrastRatio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('secondary on surface meets AA', () {
      expect(_contrastRatio(scheme.secondary, scheme.surface),
          greaterThanOrEqualTo(3.0));
    });

    test('error on surface meets AA', () {
      expect(_contrastRatio(scheme.error, scheme.surface),
          greaterThanOrEqualTo(4.5));
    });
  });
}
