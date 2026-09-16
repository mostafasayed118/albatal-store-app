import 'package:flutter/services.dart';

/// Loads the app's real fonts (pubspec `fonts:`) into the test engine.
///
/// Widget tests otherwise render with the default test font, whose uniform
/// glyph advances make copy measurably WIDER than the app's Inter/Montserrat.
/// That skew is large enough to invert a conclusion: at a 1.4 text scale on a
/// 360dp viewport every CTA label — including the ones the app already ships —
/// reports a `TextOverflow` ellipsis under the test font, while the same labels
/// fit with ~20-40dp to spare in Inter.
///
/// So any test that reasons about whether copy FITS must load these first,
/// otherwise it measures the test font rather than the app.
///
/// IMPORTANT — loading alone is not enough. A widget only renders in these
/// families if it inherits them, and the family comes from the theme. The
/// harness must apply `AppTheme.light()`; a bare `MaterialApp` leaves the
/// family null and the text falls back to the test font anyway. Measured on
/// the same grid-card price string in the same 158dp cell:
///
///   unthemed (test font)  intrinsic 112.8dp @1.0x / 157.6dp @1.4x
///   themed  (real Inter)  intrinsic  66.9dp @1.0x /  93.2dp @1.4x
Future<void> loadAppFonts() async {
  await (FontLoader('Inter')
        ..addFont(
            rootBundle.load('assets/fonts/Inter-VariableFont_opsz,wght.ttf')))
      .load();
  await (FontLoader('Montserrat')
        ..addFont(
            rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf')))
      .load();
}
