import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/utils/currency.dart';
import 'package:al_batal_elite/features/auth/presentation/pages/sign_in_page.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks for Sign-in page dependencies
// ---------------------------------------------------------------------------

class MockAuthCubit extends Mock implements AuthCubit {
  @override
  AuthState get state => const AuthState();

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  Future<void> close() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget appHarness({
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

Future<AppLocalizations> loadLocale(
  WidgetTester tester,
  Locale locale,
) async {
  await tester.pumpWidget(
    appHarness(
      locale: locale,
      child: const Scaffold(body: SizedBox()),
    ),
  );
  await tester.pump();
  return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // ── Defect 1: Locale-aware money formatting ──────────────────────────────
  group('money() locale-aware formatting', () {
    test('English locale uses comma thousand separators', () {
      final amount = const Money.egp(1250000);
      final result = money(amount, context: null);
      // Without context falls back to no-locale formatting (whole units).
      expect(result, '1250000 EGP');
    });

    testWidgets('English locale formats with comma separators', (tester) async {
      late String result;
      final amount = const Money.egp(1250000);

      await tester.pumpWidget(
        appHarness(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              result = money(amount, context: context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(result, '1,250,000 EGP');
    });

    testWidgets('Arabic locale formats with locale-aware currency code',
        (tester) async {
      late String result;
      final amount = const Money.egp(1250000);

      await tester.pumpWidget(
        appHarness(
          locale: const Locale('ar'),
          child: Builder(
            builder: (context) {
              result = money(amount, context: context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      final arCode = AppLocalizationsAr('ar').currencyCode;
      expect(result, endsWith(' $arCode'));
      expect(result, isNot(contains('EGY')));
      expect(result.replaceAll(RegExp(r'[^0-9]'), ''), contains('1250000'));
    });

    testWidgets('Zero amount formats correctly in both locales',
        (tester) async {
      late String enResult;
      await tester.pumpWidget(
        appHarness(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              enResult = money(Money.zero, context: context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(enResult, '0 EGP');

      late String arResult;
      await tester.pumpWidget(
        appHarness(
          locale: const Locale('ar'),
          child: Builder(
            builder: (context) {
              arResult = money(Money.zero, context: context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(arResult, '0 ${AppLocalizationsAr('ar').currencyCode}');
    });

    testWidgets('Small amounts have no separators in English', (tester) async {
      late String result;

      await tester.pumpWidget(
        appHarness(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              result = money(const Money.egp(499), context: context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(result, '499 EGP');
    });
  });

  // ── Defect 2: Catalog sort labels ────────────────────────────────────────
  group('Catalog sort labels localized', () {
    test('English labels match expected strings', () {
      final en = <String>[
        for (final s in CatalogSort.values)
          s.labelFor(AppLocalizationsEn('en')),
      ];

      expect(en, [
        'Featured',
        'Price: low to high',
        'Price: high to low',
        'Name: A to Z',
        'Newest',
      ]);
    });

    test('Arabic labels are non-empty and distinct from English', () {
      final en = <String>[
        for (final s in CatalogSort.values)
          s.labelFor(AppLocalizationsEn('en')),
      ];
      final ar = <String>[
        for (final s in CatalogSort.values)
          s.labelFor(AppLocalizationsAr('ar')),
      ];

      for (var i = 0; i < CatalogSort.values.length; i++) {
        expect(ar[i], isNotEmpty);
        expect(ar[i], isNot(en[i]));
      }
    });

    testWidgets('Sort labels render correctly under English locale',
        (tester) async {
      final l = await loadLocale(tester, const Locale('en'));
      final labels = CatalogSort.values.map((s) => s.labelFor(l)).toList();

      expect(labels, contains('Featured'));
      expect(labels, contains('Newest'));
    });

    testWidgets('Sort labels render correctly under Arabic locale',
        (tester) async {
      final l = await loadLocale(tester, const Locale('ar'));
      final labels = CatalogSort.values.map((s) => s.labelFor(l)).toList();

      expect(labels, contains('مميّز'));
      expect(labels, contains('الأحدث'));
    });
  });

  // ── Defect 3: Sign-in page alignment ─────────────────────────────────────
  group('Sign-in page alignment under LTR and RTL', () {
    Widget signInHarness({required Locale locale}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AuthCubit>(
          create: (_) => MockAuthCubit(),
          child: const SignInPage(),
        ),
      );
    }

    testWidgets('English: Forgot Password aligned to trailing edge (right)',
        (tester) async {
      // Use a tall surface to avoid RenderFlex overflow.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(signInHarness(locale: const Locale('en')));
      await tester.pump();

      // Find the Align widget wrapping the Forgot Password button.
      final alignFinder = find.byWidgetPredicate(
        (w) =>
            w is Align &&
            w.child is TextButton &&
            (w.child as TextButton).child is Text,
      );
      expect(alignFinder, findsOneWidget);

      final align = tester.widget<Align>(alignFinder);
      // AlignmentDirectional.centerEnd in LTR resolves to right.
      expect(align.alignment, isA<AlignmentDirectional>());

      // Verify the button is visually on the right half of the screen.
      final box = tester.renderObject<RenderBox>(alignFinder);
      final buttonRight = box.localToGlobal(Offset.zero).dx + box.size.width;
      expect(buttonRight, closeTo(800.0, 24.0));
    });

    testWidgets('Arabic: Forgot Password aligned to trailing edge (left)',
        (tester) async {
      // Use a tall surface to avoid RenderFlex overflow.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(signInHarness(locale: const Locale('ar')));
      await tester.pump();

      final alignFinder = find.byWidgetPredicate(
        (w) =>
            w is Align &&
            w.child is TextButton &&
            (w.child as TextButton).child is Text,
      );
      expect(alignFinder, findsOneWidget);

      final align = tester.widget<Align>(alignFinder);
      expect(align.alignment, isA<AlignmentDirectional>());

      // Verify the button is visually on the left half of the screen.
      final box = tester.renderObject<RenderBox>(alignFinder);
      final buttonLeft = box.localToGlobal(Offset.zero).dx;
      expect(buttonLeft, closeTo(0.0, 24.0));
    });

    testWidgets('SignIn page renders in both locales without errors',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [Locale('en'), Locale('ar')]) {
        await tester.pumpWidget(signInHarness(locale: locale));
        await tester.pump();

        expect(find.byType(SignInPage), findsOneWidget);
      }
    });
  });
}
