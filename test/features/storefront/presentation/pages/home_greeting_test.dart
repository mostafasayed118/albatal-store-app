import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // English locale is sufficient: bucket selection is locale-independent and
  // the AR strings mirror the same three forms.
  final en = AppLocalizationsEn();

  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 9, 6, hour, minute);

  group('homeGreeting buckets (UX-044)', () {
    test('morning 05:00–11:59', () {
      expect(homeGreeting(en, 'Ahmed', at(5)), 'Good morning, Ahmed');
      expect(homeGreeting(en, null, at(9)), 'Good morning');
      expect(homeGreeting(en, null, at(11, 59)), 'Good morning');
    });

    test('afternoon 12:00–16:59', () {
      expect(homeGreeting(en, 'Ahmed', at(12)), 'Good afternoon, Ahmed');
      expect(homeGreeting(en, null, at(14)), 'Good afternoon');
      expect(homeGreeting(en, null, at(16, 59)), 'Good afternoon');
    });

    test('evening 17:00–04:59', () {
      expect(homeGreeting(en, 'Ahmed', at(17)), 'Good evening, Ahmed');
      expect(homeGreeting(en, null, at(23)), 'Good evening');
      expect(homeGreeting(en, null, at(0)), 'Good evening');
      expect(homeGreeting(en, null, at(4, 59)), 'Good evening');
    });
  });
}
