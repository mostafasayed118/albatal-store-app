import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/presentation/localization/category_labels.dart';
import 'package:al_batal_elite/features/storefront/presentation/localization/product_attribute_labels.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/flash_sale_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/product_details_section.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required Locale locale,
  required Widget child,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

Future<AppLocalizations> _load(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    _harness(locale: locale, child: const Scaffold(body: SizedBox())),
  );
  await tester.pump();
  return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
}

void main() {
  // ── D1: flash-sale “20% OFF” ───────────────────────────────────────────
  group('D1 flash sale discount text', () {
    testWidgets('English flash sale uses localized flashSalePriceLine',
        (tester) async {
      final product = products.firstWhere((p) => p.id == 'silk-01');
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          child: BlocProvider(
            create: (_) => CartCubit(MemoryStorefrontPersistence()),
            child: Scaffold(body: FlashSaleCard(product: product)),
          ),
        ),
      );
      await tester.pump();

      final en = AppLocalizationsEn('en');
      final expected = en.flashSalePriceLine(
        en.discountPercent(20),
        product.price.format(locale: 'en', symbol: en.currencyCode),
      );
      expect(find.text(expected), findsOneWidget);
      // Currency code is EGP (not legacy EGY).
      expect(find.textContaining('EGY'), findsNothing);
      expect(find.textContaining(en.currencyCode), findsWidgets);
    });

    testWidgets('Arabic flash sale uses localized discount badge',
        (tester) async {
      final product = products.firstWhere((p) => p.id == 'silk-01');
      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          child: BlocProvider(
            create: (_) => CartCubit(MemoryStorefrontPersistence()),
            child: Scaffold(body: FlashSaleCard(product: product)),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('OFF'), findsNothing);
      final ar = AppLocalizationsAr('ar');
      final expected = ar.flashSalePriceLine(
        ar.discountPercent(20),
        product.price.format(locale: 'ar', symbol: ar.currencyCode),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining(ar.currencyCode), findsWidgets);
    });
  });

  // ── D2: admin unknown-customer fallback ────────────────────────────────
  group('D2 unknown customer fallback', () {
    test('unknownLabel differs between EN and AR', () {
      final en = AppLocalizationsEn('en');
      final ar = AppLocalizationsAr('ar');
      expect(en.unknownLabel, 'Unknown');
      expect(ar.unknownLabel, isNot(en.unknownLabel));
      expect(ar.unknownLabel, isNotEmpty);
    });

    testWidgets('EN and AR unknownLabel values load', (tester) async {
      final en = await _load(tester, const Locale('en'));
      final ar = await _load(tester, const Locale('ar'));
      expect(en.unknownLabel, 'Unknown');
      expect(ar.unknownLabel, isNotEmpty);
      expect(ar.unknownLabel, isNot('Unknown'));
    });
  });

  // ── D3: category labels ────────────────────────────────────────────────
  group('D3 category labels', () {
    test('wire keys map to localized display without changing wire values', () {
      final en = AppLocalizationsEn('en');
      final ar = AppLocalizationsAr('ar');

      expect(localizedCategory('All', en), en.categoryAll);
      expect(localizedCategory('Silk', en), en.categorySilk);
      expect(localizedCategory('Silk', ar), ar.categorySilk);
      expect(localizedCategory('Cotton', ar), ar.categoryCotton);
      expect(localizedCategory('Velvet', ar), ar.categoryVelvet);
      expect(localizedCategory('Linen', ar), ar.categoryLinen);
      expect(localizedCategory('Wool', ar), ar.categoryWool);

      // Unknown wire keys pass through.
      expect(localizedCategory('Custom', en), 'Custom');

      // Arabic labels are not English wire keys.
      expect(ar.categorySilk, isNot('Silk'));
      expect(ar.categoryAll, isNot('All'));
    });
  });

  // ── D4: EGP + Arabic currency ──────────────────────────────────────────
  group('D4 currency code EGP and Arabic representation', () {
    test('default Money.format uses EGP not EGY', () {
      expect(const Money.egp(1290).format(), '1290 EGP');
      expect(const Money.egp(1290).format(), isNot(contains('EGY')));
    });

    testWidgets('money() helper uses locale currencyCode', (tester) async {
      late String enResult;
      late String arResult;
      final amount = const Money.egp(1290);

      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          child: Builder(builder: (context) {
            enResult = money(amount, context: context);
            return const SizedBox();
          }),
        ),
      );
      await tester.pump();
      expect(enResult, endsWith(' EGP'));
      expect(enResult, isNot(contains('EGY')));

      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          child: Builder(builder: (context) {
            arResult = money(amount, context: context);
            return const SizedBox();
          }),
        ),
      );
      await tester.pump();
      final ar = AppLocalizationsAr('ar');
      expect(arResult, endsWith(' ${ar.currencyCode}'));
      expect(arResult, isNot(contains('EGY')));
      expect(ar.currencyCode, isNot('EGP'));
    });
  });

  // ── D11: composition / care / origin ───────────────────────────────────
  group('D11 product attribute localization', () {
    test('known compositions localize; unknown falls back', () {
      final en = AppLocalizationsEn('en');
      final ar = AppLocalizationsAr('ar');

      expect(
        localizedComposition('100% Mulberry Silk', en),
        en.compositionMulberrySilk,
      );
      expect(
        localizedComposition('100% Mulberry Silk', ar),
        ar.compositionMulberrySilk,
      );
      expect(ar.compositionMulberrySilk, isNot('100% Mulberry Silk'));
      expect(localizedComposition('Custom Blend 50%', en), 'Custom Blend 50%');
    });

    test('all seeded product attributes map for EN and AR', () {
      final en = AppLocalizationsEn('en');
      final ar = AppLocalizationsAr('ar');

      for (final p in products) {
        final enComp = localizedProductComposition(p, en);
        final arComp = localizedProductComposition(p, ar);
        expect(enComp, isNotEmpty);
        expect(arComp, isNotEmpty);
        // Known catalog rows should not leave English wire text in AR.
        if (p.composition != null) {
          expect(arComp, isNot(p.composition));
        }
        if (p.care != null) {
          expect(localizedProductCare(p, ar), isNot(p.care));
        }
        if (p.origin != null) {
          expect(localizedProductOrigin(p, ar), isNot(p.origin));
        }
      }
    });

    testWidgets('ProductDetailsSection renders Arabic attributes',
        (tester) async {
      final product = products.firstWhere((p) => p.id == 'silk-01');
      final ar = AppLocalizationsAr('ar');
      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          child: Scaffold(
            body: ProductDetailsSection(
              product: product,
              l: ar,
            ),
          ),
        ),
      );
      await tester.pump();

      // InfoRow uses RichText; match via plain text extraction.
      bool richContains(String needle) => find
          .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains(needle),
          )
          .evaluate()
          .isNotEmpty;

      expect(richContains(ar.compositionMulberrySilk), isTrue);
      expect(richContains(ar.originVaranasiIndia), isTrue);
      expect(find.textContaining(ar.careDryCleanSilk), findsOneWidget);
      expect(richContains('100% Mulberry Silk'), isFalse);
      expect(richContains('Varanasi, India'), isFalse);
      expect(
        find.textContaining(
            'Dry clean only. Cool iron on reverse. Store folded in breathable cotton.'),
        findsNothing,
      );
    });
  });
}
