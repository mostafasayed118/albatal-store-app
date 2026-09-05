import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders [pick] under the given [locale] via the real localization
/// delegate (which loads intl plural data for that locale), mirroring how
/// production widgets resolve copy.
Future<String> _render(
  WidgetTester tester,
  Locale locale,
  String Function(AppLocalizations) pick,
) async {
  late String out;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Builder(
      builder: (context) {
        out = pick(AppLocalizations.of(context)!);
        return const SizedBox.shrink();
      },
    ),
  ));
  return out;
}

void main() {
  group('English count plurals', () {
    final en = AppLocalizationsEn();

    test('fabricsFound agrees for 0/1/many', () {
      expect(en.fabricsFound(0), 'No fabrics found');
      expect(en.fabricsFound(1), '1 fabric found');
      expect(en.fabricsFound(3), '3 fabrics found');
    });

    test('curatedFabrics singularizes 1', () {
      expect(en.curatedFabrics(0), 'No curated fabrics');
      expect(en.curatedFabrics(1), '1 curated fabric');
      expect(en.curatedFabrics(3), '3 curated fabrics');
    });

    test('itemsCount singularizes 1', () {
      expect(en.itemsCount(1), '1 item');
      expect(en.itemsCount(2), '2 items');
    });
  });

  group('Arabic count plurals (CLDR)', () {
    testWidgets('curatedFabrics uses zero/one/two/few/many', (tester) async {
      Future<String> s(int n) =>
          _render(tester, const Locale('ar'), (l) => l.curatedFabrics(n));

      expect(await s(0), 'لا أقمشة مختارة');
      expect(await s(1), 'قماش مختار واحد');
      expect(await s(2), 'قماشان مختاران');
      expect(await s(3), '3 أقمشة مختارة');
      expect(await s(11), '11 قماشًا مختارًا');
    });

    testWidgets('itemsCount agrees across categories', (tester) async {
      Future<String> s(int n) =>
          _render(tester, const Locale('ar'), (l) => l.itemsCount(n));

      expect(await s(1), 'عنصر واحد');
      expect(await s(2), 'عنصران');
      expect(await s(5), '5 عناصر');
      expect(await s(12), '12 عنصرًا');
    });

    testWidgets('fabricsFound agrees across categories', (tester) async {
      Future<String> s(int n) =>
          _render(tester, const Locale('ar'), (l) => l.fabricsFound(n));

      expect(await s(0), 'لا توجد أقمشة');
      expect(await s(1), 'قماش واحد');
      expect(await s(3), '3 أقمشة');
      expect(await s(11), '11 قماشًا');
    });
  });

  group('wishlist empty copy (UX-045)', () {
    testWidgets('AR and EN wishlist-specific strings exist', (tester) async {
      final en = await _render(
          tester, const Locale('en'), (l) => l.wishlistEmptyTitle);
      final ar = await _render(
          tester, const Locale('ar'), (l) => l.wishlistEmptyTitle);
      expect(en, 'Your wishlist is empty');
      expect(ar, 'قائمة مفضلتك فارغة');
    });
  });
}
