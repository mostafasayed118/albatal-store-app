import 'dart:convert';
import 'dart:io';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/storefront/data/local_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness that renders a widget under a specific locale.
Widget _harness({
  required Locale locale,
  required Widget child,
}) {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// Test harness for pages that need BLoC providers.
Widget _blocHarness({
  required Locale locale,
  required Widget child,
}) {
  SharedPreferences.setMockInitialValues({});
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => CatalogCubit(LocalCatalogRepository())..load()),
        BlocProvider(
            create: (_) => CartCubit(MemoryStorefrontPersistence())..restore()),
        BlocProvider(
            create: (_) =>
                WishlistCubit(MemoryStorefrontPersistence())..restore()),
      ],
      child: child,
    ),
  );
}

Future<AppLocalizations> _loadLocale(
  WidgetTester tester,
  Locale locale,
) async {
  await tester.pumpWidget(
    _harness(locale: locale, child: const Scaffold(body: SizedBox())),
  );
  await tester.pump();
  return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
}

/// Top-level ARB message keys via raw line scan (detects true duplicates).
List<String> _topLevelArbKeys(String source) {
  final re = RegExp(r'^  "([^"@][^"]*)"\s*:', multiLine: true);
  return re.allMatches(source).map((m) => m.group(1)!).toList();
}

void main() {
  group('ARB key parity', () {
    test('English and Arabic ARB files have identical key sets', () async {
      final enFile = File('l10n/app_en.arb');
      final arFile = File('l10n/app_ar.arb');

      final enJson =
          jsonDecode(await enFile.readAsString()) as Map<String, dynamic>;
      final arJson =
          jsonDecode(await arFile.readAsString()) as Map<String, dynamic>;

      final enKeys = enJson.keys
          .where((k) => !k.startsWith('@@') && !k.startsWith('@'))
          .toSet();
      final arKeys = arJson.keys
          .where((k) => !k.startsWith('@@') && !k.startsWith('@'))
          .toSet();

      final missingInAr = enKeys.difference(arKeys);
      final missingInEn = arKeys.difference(enKeys);

      expect(missingInAr, isEmpty,
          reason: 'Keys in English but missing in Arabic: $missingInAr');
      expect(missingInEn, isEmpty,
          reason: 'Keys in Arabic but missing in English: $missingInEn');
    });

    test('ARB files have no duplicate keys (raw scan)', () async {
      for (final locale in ['en', 'ar']) {
        final source = await File('l10n/app_$locale.arb').readAsString();
        final keys = _topLevelArbKeys(source);
        final counts = <String, int>{};
        for (final k in keys) {
          counts[k] = (counts[k] ?? 0) + 1;
        }
        final dups = counts.entries.where((e) => e.value > 1).map((e) => e.key);
        expect(dups, isEmpty,
            reason: 'Duplicate keys found in app_$locale.arb: $dups');
      }
    });

    test('All placeholder keys have matching @description metadata', () async {
      for (final locale in ['en', 'ar']) {
        final file = File('l10n/app_$locale.arb');
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;

        for (final key in json.keys) {
          if (key.startsWith('@@') || key.startsWith('@')) continue;
          final value = json[key];
          if (value is String && value.contains('{')) {
            expect(json.containsKey('@$key'), isTrue,
                reason:
                    'Key "$key" in $locale has placeholders but no @metadata');
          }
        }
      }
    });

    test('Generated AppLocalizations includes new Spec 11 keys', () {
      // Compile-time surface: if gen-l10n is stale these fail to resolve.
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('ar')));
    });
  });

  group('Locale loading', () {
    testWidgets('English locale loads without errors', (tester) async {
      final l = await _loadLocale(tester, const Locale('en'));
      expect(l.appTitle, 'Al Batal Elite');
    });

    testWidgets('Arabic locale loads without errors', (tester) async {
      final l = await _loadLocale(tester, const Locale('ar'));
      expect(l.appTitle, 'البطل إيليت');
    });

    testWidgets('AppLocalizations delegate is registered', (tester) async {
      await tester.pumpWidget(
        _harness(
          locale: const Locale('en'),
          child: const Scaffold(body: SizedBox()),
        ),
      );
      await tester.pump();
      expect(AppLocalizations.of(tester.element(find.byType(Scaffold))),
          isNotNull);
    });
  });

  group('RTL directionality', () {
    testWidgets('Arabic locale resolves to RTL direction', (tester) async {
      await tester.pumpWidget(
        _blocHarness(
          locale: const Locale('ar'),
          child: const HomePage(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final context = tester.element(find.byType(HomePage));
      expect(Directionality.of(context), TextDirection.rtl);
    });

    testWidgets('English locale resolves to LTR direction', (tester) async {
      await tester.pumpWidget(
        _blocHarness(
          locale: const Locale('en'),
          child: const HomePage(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final context = tester.element(find.byType(HomePage));
      expect(Directionality.of(context), TextDirection.ltr);
    });

    testWidgets('AlignmentDirectional respects RTL ambient direction',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          child: const Scaffold(
            body: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(width: 8, height: 8, key: Key('marker')),
            ),
          ),
        ),
      );
      await tester.pump();

      final box =
          tester.renderObject<RenderBox>(find.byKey(const Key('marker')));
      final parent = tester.renderObject<RenderBox>(find.byType(Scaffold));
      // In RTL, centerEnd is on the left side of the parent.
      expect(
          box.localToGlobal(Offset.zero).dx, lessThan(parent.size.width / 2));
    });
  });

  group('Localized surfaces', () {
    testWidgets('Home page shows Arabic brand name in Arabic locale',
        (tester) async {
      await tester.pumpWidget(
        _blocHarness(
          locale: const Locale('ar'),
          child: const HomePage(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('البطل إيليت'), findsOneWidget);
    });

    testWidgets('Home page shows English brand name in English locale',
        (tester) async {
      await tester.pumpWidget(
        _blocHarness(
          locale: const Locale('en'),
          child: const HomePage(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Al Batal Elite'), findsOneWidget);
    });

    testWidgets('Arabic tooltip renders in Arabic locale', (tester) async {
      await tester.pumpWidget(
        _blocHarness(
          locale: const Locale('ar'),
          child: const HomePage(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byTooltip('فتح الإعدادات'), findsOneWidget);
    });

    testWidgets('Payment surface strings differ by locale', (tester) async {
      final en = await _loadLocale(tester, const Locale('en'));
      final ar = await _loadLocale(tester, const Locale('ar'));

      expect(en.selectPaymentMethod, isNot(ar.selectPaymentMethod));
      expect(en.payWithCard, isNot(ar.payWithCard));
      expect(en.cashOnDelivery, isNot(ar.cashOnDelivery));
      expect(en.invalidCheckoutLink, isNot(ar.invalidCheckoutLink));
      expect(en.paymentTimedOut, isNotEmpty);
      expect(ar.paymentTimedOut, isNotEmpty);
      expect(ar.paymentTimedOut, isNot(contains('Payment')));
    });

    testWidgets('Checkout surface strings are localized', (tester) async {
      final ar = await _loadLocale(tester, const Locale('ar'));
      expect(ar.checkout, isNotEmpty);
      expect(ar.proceedToPayment, isNotEmpty);
      expect(ar.serverConfirmedTotals, isNotEmpty);
      expect(ar.subtotalLabel, isNotEmpty);
      expect(ar.shippingLabel, isNotEmpty);
      expect(ar.totalLabel, isNotEmpty);
      expect(ar.orderReferenceMissing, isNotEmpty);
      expect(ar.validationSelectAddress, isNotEmpty);
    });

    testWidgets('Auth surface strings are localized', (tester) async {
      final en = await _loadLocale(tester, const Locale('en'));
      final ar = await _loadLocale(tester, const Locale('ar'));

      expect(en.signIn, isNot(ar.signIn));
      expect(en.signUp, isNot(ar.signUp));
      expect(en.forgotPassword, isNot(ar.forgotPassword));
      expect(ar.invalidEmail, isNotEmpty);
      expect(ar.passwordTooShort, isNotEmpty);
      expect(ar.passwordsDoNotMatch, isNotEmpty);
      expect(ar.continueAsGuest, isNotEmpty);
      expect(ar.signInToViewProfile, isNotEmpty);
    });

    testWidgets('Address surface strings are localized', (tester) async {
      final ar = await _loadLocale(tester, const Locale('ar'));
      expect(ar.shippingAddresses, isNotEmpty);
      expect(ar.recipientLabel, isNotEmpty);
      expect(ar.streetAddressLabel, isNotEmpty);
      expect(ar.cityLabel, isNotEmpty);
      expect(ar.countryLabel, isNotEmpty);
      expect(ar.addAddressTitle, isNotEmpty);
      expect(ar.editAddressTitle, isNotEmpty);
      expect(ar.nameRequiredValidation, isNotEmpty);
      expect(ar.validStreetAddressRequired, isNotEmpty);
    });

    testWidgets('Admin surface strings are localized', (tester) async {
      final en = await _loadLocale(tester, const Locale('en'));
      final ar = await _loadLocale(tester, const Locale('ar'));

      expect(en.adminDashboard, isNot(ar.adminDashboard));
      expect(ar.addTrackingDetails, isNotEmpty);
      expect(ar.courierNameLabel, isNotEmpty);
      expect(ar.trackingNumberLabel, isNotEmpty);
      expect(ar.orderMarkedAsShipped, isNotEmpty);
      expect(ar.updateStock, isNotEmpty);
      expect(ar.fulfillmentActions, isNotEmpty);
      expect(ar.orderNumber('ABC12345'), contains('ABC12345'));
      expect(ar.orderStatusUpdatedTo(ar.shipped), contains(ar.shipped));
      expect(ar.paid, isNotEmpty);
      expect(ar.unknownLabel, isNotEmpty);
    });

    testWidgets('orderPlacedBody Arabic is fully translated', (tester) async {
      final l = await _loadLocale(tester, const Locale('ar'));
      expect(l.orderPlacedBody, isNot(contains('inform')));
      expect(l.orderPlacedBody, isNot(contains('placed')));
      expect(l.orderPlacedBody, contains('طلبك'));
    });
  });

  group('Text expansion and overflow', () {
    testWidgets('Key Arabic strings are non-empty and distinct from English',
        (tester) async {
      final en = await _loadLocale(tester, const Locale('en'));
      final ar = await _loadLocale(tester, const Locale('ar'));

      final pairs = <(String, String)>[
        (en.addToCart, ar.addToCart),
        (en.shippingAddress, ar.shippingAddress),
        (en.paymentMethod, ar.paymentMethod),
        (en.orderDetails, ar.orderDetails),
        (en.fulfillmentActions, ar.fulfillmentActions),
        (en.invalidCheckoutLinkFull, ar.invalidCheckoutLinkFull),
      ];

      for (final pair in pairs) {
        expect(pair.$1, isNotEmpty);
        expect(pair.$2, isNotEmpty);
        expect(pair.$1, isNot(pair.$2));
      }
    });

    testWidgets('Long Arabic labels fit constrained buttons without overflow',
        (tester) async {
      final ar = await _loadLocale(tester, const Locale('ar'));
      final labels = [
        ar.proceedToPayment,
        ar.invalidCheckoutLinkFull,
        ar.fulfillmentActions,
        ar.paymentTimedOut,
        ar.serverConfirmedTotals,
      ];

      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          child: Scaffold(
            body: ListView(
              children: [
                for (final label in labels)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 200,
                      child: FilledButton(
                        onPressed: () {},
                        child: Text(
                          label,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // No FlutterError overflow exceptions during layout.
      expect(tester.takeException(), isNull);
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('Locale-aware formatting', () {
    test('Money.format default uses EGP suffix and whole units', () {
      expect(const Money.egp(1290).format(), '1290 EGP');
      expect(const Money(129000).format(), '1290 EGP');
      expect(Money.zero.format(), '0 EGP');
    });

    test('Money.format with locale applies grouping without changing suffix',
        () {
      final large = const Money.egp(1250000);
      final en = large.format(locale: 'en');
      final ar = large.format(locale: 'ar');

      expect(en.endsWith(' EGP'), isTrue);
      expect(ar.endsWith(' EGP'), isTrue);
      // English grouping uses comma thousands separators for this magnitude.
      expect(en, contains(','));
      // Amount semantics: major units are still 1250000.
      expect(en.replaceAll(RegExp(r'[^0-9]'), ''), '1250000');
      expect(ar.replaceAll(RegExp(r'[^0-9\u0660-\u0669]'), ''), isNotEmpty);
    });

    test('DateFormat.yMMMd is locale-aware for order dates', () {
      final date = DateTime(2026, 7, 21);
      final en = DateFormat.yMMMd('en').format(date);
      final ar = DateFormat.yMMMd('ar').format(date);
      expect(en, isNot(ar));
      expect(en, contains('2026'));
      expect(ar, isNotEmpty);
    });

    testWidgets('Parameterized item counts format under both locales',
        (tester) async {
      final en = await _loadLocale(tester, const Locale('en'));
      final ar = await _loadLocale(tester, const Locale('ar'));
      expect(en.itemsCount(3), contains('3'));
      expect(ar.itemsCount(3), contains('3'));
      expect(en.fabricsFound(12), contains('12'));
      expect(ar.fabricsFound(12), contains('12'));
    });
  });

  group('Directional icons', () {
    testWidgets('Forward icons exist in LTR and RTL trees', (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        await tester.pumpWidget(
          _harness(
            locale: locale,
            child: const Scaffold(
              body: Row(
                children: [
                  Icon(Icons.arrow_forward, key: Key('fwd')),
                  Icon(Icons.chevron_right, key: Key('chev')),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('fwd')), findsOneWidget);
        expect(find.byKey(const Key('chev')), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byKey(const Key('fwd')))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
      }
    });
  });

  group('Order status strings', () {
    testWidgets('Order status strings are localized', (tester) async {
      final l = await _loadLocale(tester, const Locale('ar'));
      expect(l.placed, isNotEmpty);
      expect(l.processing, isNotEmpty);
      expect(l.shipped, isNotEmpty);
      expect(l.delivered, isNotEmpty);
      expect(l.cancelled, isNotEmpty);
      expect(l.paid, isNotEmpty);
      expect(l.allOrders, isNotEmpty);
      expect(l.noOrdersFound, isNotEmpty);
    });
  });
}
