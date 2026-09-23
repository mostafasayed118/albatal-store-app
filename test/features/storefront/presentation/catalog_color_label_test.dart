import 'package:al_batal_elite/features/storefront/presentation/catalog_color_label.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression pin (audit 2026-09-21 M-03 / UX-031): color names are DATA
/// and were rendered verbatim, so an Arabic session read English filter
/// and variant chips inside localized chrome.
void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  test('curated vocabulary resolves to exact English copy', () {
    expect(catalogColorLabel(en, 'Emerald'), 'Emerald');
    expect(catalogColorLabel(en, 'gold'), 'Gold'); // case-insensitive
    expect(catalogColorLabel(en, ' Other '), 'Other'); // trims
  });

  test('no curated color falls back to English in Arabic', () {
    const names = [
      'Emerald',
      'Gold',
      'Ivory',
      'Purple',
      'Beige',
      'Brown',
      'Amber',
      'Teal',
      'Crimson',
      'Sand',
      'Other',
    ];
    for (final name in names) {
      final arabic = catalogColorLabel(ar, name);
      expect(arabic, isNotEmpty, reason: '$name is empty in Arabic');
      expect(arabic, isNot(catalogColorLabel(en, name)),
          reason: '$name is still English in Arabic');
    }
  });

  test('unknown DB values pass through instead of disappearing', () {
    expect(catalogColorLabel(en, 'Zanzibar'), 'Zanzibar');
    expect(catalogColorLabel(ar, 'زمردي'), 'زمردي');
  });
}
