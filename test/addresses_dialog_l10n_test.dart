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

/// The addresses-book add/edit dialog must speak the user's locale — same
/// hardcoded-English class as the checkout sheet (labels, title, actions,
/// and the per-field "is required" error).
Widget _harness({Locale? locale}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => AddressesCubit(_StubAddressRepository())..load(),
        child: const AddressesPage(),
      ),
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Address').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('address dialog copy resolves via l10n (EN)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openDialog(tester);

    // Title + opener button share the addAddress copy.
    expect(find.text('Add Address'), findsNWidgets(2));
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('address dialog copy resolves via l10n (AR)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة عنوان').first);
    await tester.pumpAndSettle();

    expect(find.text('إضافة عنوان'), findsNWidgets(2));
    expect(find.text('المستلم'), findsOneWidget);
    expect(find.text('عنوان الشارع'), findsOneWidget);
    expect(find.text('المدينة'), findsOneWidget);
    expect(find.text('البلد'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  testWidgets('address dialog empty submit shows the generic required error',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await _openDialog(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsNWidgets(4));
  });
}
