import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocale.fromLanguageCode', () {
    test('maps supported language codes', () {
      expect(AppLocale.fromLanguageCode('en'), AppLocale.english);
      expect(AppLocale.fromLanguageCode('ar'), AppLocale.arabic);
    });

    test('degrades unknown codes to English instead of throwing', () {
      expect(AppLocale.fromLanguageCode('fr'), AppLocale.english);
      expect(AppLocale.fromLanguageCode(''), AppLocale.english);
      expect(AppLocale.fromLanguageCode(null), AppLocale.english);
    });
  });

  group('AppThemeMode', () {
    test('names mirror Material ThemeMode for lossless persistence', () {
      // The data layer persists `mode.name`; the values must stay aligned
      // with Material's ThemeMode names so saved prefs remain readable.
      expect(
        AppThemeMode.values.map((m) => m.name),
        ['system', 'light', 'dark'],
      );
    });
  });
}
