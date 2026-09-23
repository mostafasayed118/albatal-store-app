import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/addresses/presentation/pages/addresses_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAddressRepository implements AddressRepository {
  @override
  Future<Result<List<Address>>> read() async => const Success([]);
  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

/// The address book opens the SHARED address form (2026-09-23 unification):
/// the same bottom sheet the checkout flow uses, with the "Save" submit copy
/// instead of "Continue". The old book-only dialog — no phone field, no
/// numeric keyboard, weaker validation — is gone.
Widget _harness({Locale? locale}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => AddressesCubit(_StubAddressRepository())..load(),
        child: const AddressesPage(),
      ),
    );

Future<void> _openForm(WidgetTester tester, String fabLabel) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text(fabLabel).first);
  await tester.pumpAndSettle();
}

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
  testWidgets('address book form copy resolves via l10n (EN)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester, 'Add Address');

    expect(find.text('Add New Address'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    // The book saves; the checkout flow continues.
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('address book form copy resolves via l10n (AR)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await _openForm(tester, 'إضافة عنوان');

    expect(find.text('إضافة عنوان جديد'), findsOneWidget);
    expect(find.text('الاسم الكامل'), findsOneWidget);
    expect(find.text('رقم الهاتف'), findsOneWidget);
    expect(find.text('عنوان الشارع'), findsOneWidget);
    expect(find.text('المدينة'), findsOneWidget);
    expect(find.text('البلد'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  testWidgets('empty submit shows per-field validator copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester, 'Add Address');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Field-specific copy — the old dialog's generic "This field is
    // required" went away with the duplicate form.
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid Egyptian mobile number (e.g. 01012345678)'),
        findsOneWidget);
    expect(find.text('Enter a valid street address'), findsOneWidget);
    expect(find.text('City is required'), findsOneWidget);
    expect(find.text('Country is required'), findsOneWidget);
    expect(find.text('This field is required'), findsNothing);
  });

  testWidgets('an invalid phone blocks the save; a valid one closes the sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openForm(tester, 'Add Address');

    await _fillValid(tester, phone: '12345');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget, reason: 'sheet stays open');
    expect(find.text('Enter a valid Egyptian mobile number (e.g. 01012345678)'),
        findsOneWidget);

    await _fillValid(tester, phone: '010 1234 5678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsNothing, reason: 'saved and closed');
  });
}
