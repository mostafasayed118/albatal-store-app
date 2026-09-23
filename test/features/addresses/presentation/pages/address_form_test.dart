import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/features/addresses/presentation/widgets/address_form.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('Open Form'));
  await tester.pumpAndSettle();
}

/// Same sheet, opened in EDIT mode with the address-book copy ("Save") so
/// the prefill/identity contract can be asserted end to end.
Widget _editHarness(Address initial) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final address = await AddressForm.show(context,
                  initial: initial, submitLabel: 'Save');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(address?.toString() ?? 'cancelled')),
                );
              }
            },
            child: const Text('Edit Form'),
          ),
        ),
      ),
    );

/// Fills every field with valid values; [phone] is overridable so the
/// invalid-phone test can submit a bad number with everything else clean.
Future<void> _fillValid(WidgetTester tester,
    {String phone = '01012345678'}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'), 'Sara Ahmed');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'), phone);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Street address'), '45 Nile Corniche');
  await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Cairo');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Country'), 'Egypt');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('address form shows all fields and submit button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('empty submission shows validation errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid Egyptian mobile number (e.g. 01012345678)'),
        findsOneWidget);
    expect(find.text('Enter a valid street address'), findsOneWidget);
    expect(find.text('City is required'), findsOneWidget);
    expect(find.text('Country is required'), findsOneWidget);
  });

  testWidgets('valid submission pops with Address',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    await _fillValid(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Should show the snackbar with the address string.
    expect(find.textContaining('Sara Ahmed'), findsOneWidget);
    expect(find.textContaining('45 Nile Corniche'), findsOneWidget);
    // The typed country must survive submission (live-found 2026-09-04:
    // the form validated Country yet popped it as '').
    expect(find.textContaining('Egypt'), findsOneWidget);
    // The typed phone must survive submission too (UX-003): the courier
    // dials the snapshot, so it may not be dropped on the floor.
    expect(find.textContaining('01012345678'), findsOneWidget);
  });

  testWidgets('invalid phone blocks submission', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    await _fillValid(tester, phone: '12345');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The sheet never popped (no snackbar) and the phone error is showing.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Enter a valid Egyptian mobile number (e.g. 01012345678)'),
        findsOneWidget);
  });

  testWidgets('separator-typed phone is accepted', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester);

    // Customers paste what their contacts app shows: separators must not
    // fail validation (the value is stored as typed; the admin directory's
    // digit search is separator-proof server-side, migration 065).
    await _fillValid(tester, phone: '+20 101 234 5678');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('+20 101 234 5678'), findsOneWidget);
  });

  testWidgets('editing prefills every field and preserves identity',
      (WidgetTester tester) async {
    // The unified form serves the address book's edit flow too (2026-09-23):
    // an edit must keep the id (the server treats it as an opaque key) and
    // the default mark, or editing would duplicate the row and drop the
    // customer's default choice.
    const existing = Address(
      id: 'addr-keep-me',
      recipient: 'Layla Hassan',
      phone: '01012345678',
      line: '12 Nile Street',
      city: 'Giza',
      country: 'Egypt',
      isDefault: true,
    );
    await tester.pumpWidget(_editHarness(existing));
    await tester.tap(find.text('Edit Form'));
    await tester.pumpAndSettle();

    expect(find.text('Edit address'), findsOneWidget);
    expect(find.text('Layla Hassan'), findsOneWidget);
    expect(find.text('01012345678'), findsOneWidget);
    expect(find.text('12 Nile Street'), findsOneWidget);
    expect(find.text('Giza'), findsOneWidget);

    // A phone-less legacy row can be completed in place.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'), '01112345678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Equatable's toString joins prop VALUES (no labels), and Address's
    // props end with (…, phone, isDefault): the id must survive, the phone
    // must be the edited one, and the default mark must still be true.
    expect(find.textContaining('addr-keep-me'), findsOneWidget);
    expect(find.textContaining('01112345678, true'), findsOneWidget);
  });
}
