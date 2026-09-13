import 'package:al_batal_elite/features/storefront/presentation/widgets/address_form.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The checkout address sheet must speak the user's locale — labels and
/// validators were hardcoded English on an Arabic-visible path.
Widget _harness({Locale? locale}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => AddressForm.show(context),
            child: const Text('Open Form'),
          ),
        ),
      ),
    );

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('Open Form'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('address form labels resolve via l10n (EN)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
  });

  testWidgets('address form validators resolve via l10n (EN)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid street address'), findsOneWidget);
    expect(find.text('City is required'), findsOneWidget);
    expect(find.text('Country is required'), findsOneWidget);
  });

  testWidgets('address form labels resolve via l10n (AR)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await _openForm(tester);

    expect(find.text('الاسم الكامل'), findsOneWidget);
    expect(find.text('عنوان الشارع'), findsOneWidget);
    expect(find.text('المدينة'), findsOneWidget);
    expect(find.text('البلد'), findsOneWidget);
  });

  testWidgets('address form validators resolve via l10n (AR)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await _openForm(tester);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    expect(find.text('الاسم مطلوب'), findsOneWidget);
    expect(find.text('أدخل عنوان شارع صالحًا'), findsOneWidget);
    expect(find.text('المدينة مطلوبة'), findsOneWidget);
    expect(find.text('البلد مطلوب'), findsOneWidget);
  });
}
