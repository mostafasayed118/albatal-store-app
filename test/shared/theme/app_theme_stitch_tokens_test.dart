import 'package:flutter_test/flutter_test.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';

void main() {
  group('AppTheme Stitch tokens — full map (audit medium)', () {
    test('light scaffold is Stitch #f9f9f9 and primary #003527', () {
      final t = AppTheme.light();
      // Use toARGB32() (non-deprecated) to avoid analyze info; equivalent to .value
      expect(t.scaffoldBackgroundColor.toARGB32(), 0xFFF9F9F9);
      expect(t.colorScheme.primary.toARGB32(), 0xFF003527);
      expect(t.colorScheme.secondaryContainer.toARGB32(), 0xFFFE932C);
    });

    test('light ColorScheme matches DESIGN.md Stitch map', () {
      final t = AppTheme.light();
      final cs = t.colorScheme;
      expect(cs.primary.toARGB32(), 0xFF003527, reason: 'light primary');
      expect(cs.primaryContainer.toARGB32(), 0xFF064E3B,
          reason: 'light primaryContainer');
      expect(cs.secondary.toARGB32(), 0xFF904D00, reason: 'light secondary');
      expect(cs.secondaryContainer.toARGB32(), 0xFFFE932C,
          reason: 'light secondaryContainer');
      expect(cs.tertiary.toARGB32(), 0xFF531E00, reason: 'light tertiary');
      expect(cs.surface.toARGB32(), 0xFFFFFFFF, reason: 'light surface');
      expect(t.scaffoldBackgroundColor.toARGB32(), 0xFFF9F9F9,
          reason: 'light scaffold');
      expect(cs.surfaceContainerLow.toARGB32(), 0xFFF3F3F3,
          reason: 'light surfaceContainerLow');
      expect(cs.surfaceContainer.toARGB32(), 0xFFEEEEEE,
          reason: 'light surfaceContainer');
      expect(cs.surfaceContainerHigh.toARGB32(), 0xFFE8E8E8,
          reason: 'light surfaceContainerHigh');
      expect(cs.onSurface.toARGB32(), 0xFF1A1C1C, reason: 'light onSurface');
      expect(cs.outline.toARGB32(), 0xFF707974, reason: 'light outline');
      expect(cs.outlineVariant.toARGB32(), 0xFFBFC9C3,
          reason: 'light outlineVariant');
    });

    test('dark ColorScheme matches DESIGN.md Stitch map', () {
      final t = AppTheme.dark();
      final cs = t.colorScheme;
      expect(cs.primary.toARGB32(), 0xFF95D3BA, reason: 'dark primary');
      expect(cs.onPrimary.toARGB32(), 0xFF002117, reason: 'dark onPrimary');
      expect(cs.secondary.toARGB32(), 0xFFFFB77D, reason: 'dark secondary');
      expect(cs.surface.toARGB32(), 0xFF1E293B, reason: 'dark surface (slate)');
      expect(t.scaffoldBackgroundColor.toARGB32(), 0xFF121212,
          reason: 'dark scaffold (charcoal)');
    });

    test('radius tokens are Stitch-exact', () {
      // cardRadius 16, controlRadius 8 — DESIGN.md rounded
      expect(AppTheme.cardRadius.topLeft.x, 16);
      expect(AppTheme.cardRadius.topLeft.y, 16);
      expect(AppTheme.controlRadius.topLeft.x, 8);
      expect(AppTheme.controlRadius.topLeft.y, 8);
    });

    test('typography is Montserrat + Inter', () {
      final light = AppTheme.light();
      expect(light.textTheme.displayLarge?.fontFamily, 'Montserrat',
          reason: 'headings are Montserrat');
      expect(light.textTheme.headlineLarge?.fontFamily, 'Montserrat');
      expect(light.textTheme.titleLarge?.fontFamily, 'Montserrat');
      // Body/label use Inter (ThemeData fontFamily = Inter; headings override to Montserrat)
      // Body styles inherit Inter via ThemeData; verify they are not Montserrat.
      expect(light.textTheme.bodyLarge?.fontFamily != 'Montserrat', isTrue,
          reason: 'bodyLarge not Montserrat (is Inter via ThemeData)');
      expect(light.textTheme.bodyMedium?.fontFamily != 'Montserrat', isTrue,
          reason: 'bodyMedium not Montserrat (is Inter)');
      expect(light.textTheme.labelLarge?.fontFamily != 'Montserrat', isTrue,
          reason: 'labelLarge not Montserrat (is Inter)');
    });
  });
}
