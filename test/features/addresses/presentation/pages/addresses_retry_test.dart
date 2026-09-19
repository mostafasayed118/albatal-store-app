import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/addresses/presentation/pages/addresses_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a scripted sequence of reads and counts them, so a retry is
/// observable at the repository boundary rather than inferred from the UI.
class _ScriptedAddressRepository implements AddressRepository {
  _ScriptedAddressRepository(this._results);

  final List<Result<List<Address>>> _results;
  int reads = 0;

  @override
  Future<Result<List<Address>>> read() async {
    final index = reads < _results.length ? reads : _results.length - 1;
    reads++;
    return _results[index];
  }

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

Widget _harness(AddressesCubit cubit) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => cubit..load(),
        child: const AddressesPage(),
      ),
    );

void main() {
  testWidgets('error state retries through the repository and renders the book',
      (WidgetTester tester) async {
    final repo = _ScriptedAddressRepository([
      const Failure(AppError('offline')),
      const Success([
        Address(
          id: 'a1',
          recipient: 'Sara Ahmed',
          line: '45 Nile Corniche',
          city: 'Cairo',
          country: 'Egypt',
        ),
      ]),
    ]);

    await tester.pumpWidget(_harness(AddressesCubit(repo)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(repo.reads, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(repo.reads, 2,
        reason: 'the retry refetches instead of only clearing the error');
    expect(find.text('offline'), findsNothing);
    expect(find.text('Sara Ahmed'), findsOneWidget);
  });

  testWidgets('empty book keeps the FAB as the only add entry point',
      (WidgetTester tester) async {
    final repo = _ScriptedAddressRepository([const Success([])]);

    await tester.pumpWidget(_harness(AddressesCubit(repo)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.text('No addresses saved yet'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing,
        reason: 'the add-address FAB owns the action, so no CTA duplicates it');
    expect(find.text('Add Address'), findsOneWidget,
        reason: 'a duplicated CTA would break the dialog l10n test counts');
  });
}
