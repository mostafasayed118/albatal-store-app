import 'package:al_batal_elite/features/storefront/presentation/widgets/address_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_batal_elite/generated/l10n/app_localizations.dart';

Widget _harness() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final address = await AddressForm.show(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(address?.toString() ?? 'cancelled')),
                );
              }
            },
            child: const Text('Open Form'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('address form shows all fields and submit button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('empty submission shows validation errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid street address'), findsOneWidget);
    expect(find.text('City is required'), findsOneWidget);
    expect(find.text('Country is required'), findsOneWidget);
  });

  testWidgets('valid submission pops with Address',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Sara Ahmed');
    await tester.enterText(find.widgetWithText(TextFormField, 'Street address'),
        '45 Nile Corniche');
    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Cairo');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Country'), 'Egypt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Should show the snackbar with the address string.
    expect(find.textContaining('Sara Ahmed'), findsOneWidget);
    expect(find.textContaining('45 Nile Corniche'), findsOneWidget);
  });
}
