import 'dart:async';

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/address_picker.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/empty_address_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves scripted reads and counts them, so the retry is observable at the
/// repository boundary instead of inferred from the UI.
final class _ScriptedAddressRepository implements AddressRepository {
  _ScriptedAddressRepository(this._reads);

  final List<Future<Result<List<Address>>>> _reads;
  int reads = 0;

  @override
  Future<Result<List<Address>>> read() {
    final index = reads < _reads.length ? reads : _reads.length - 1;
    reads++;
    return _reads[index];
  }

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

Widget _harness(AddressesCubit cubit) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: Builder(
          builder: (context) => Scaffold(
            body: AddressPicker(
              selectedAddress: null,
              onSelect: (_) {},
              onAddNew: () {},
              l: AppLocalizations.of(context)!,
              scheme: Theme.of(context).colorScheme,
              hasError: false,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a failed read shows an error with a retry that reloads the book',
      (tester) async {
    final repo = _ScriptedAddressRepository([
      Future.value(const Failure(AppError('offline'))),
      Future.value(const Success([
        Address(
          id: 'a1',
          recipient: 'Sara Ahmed',
          line: '45 Nile Corniche',
          city: 'Cairo',
          country: 'Egypt',
        ),
      ])),
    ]);
    final cubit = AddressesCubit(repo);
    addTearDown(cubit.close);
    unawaited(cubit.load());

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(EmptyAddressCard), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(repo.reads, 2, reason: 'retry must refetch, not just clear');
    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('an empty book keeps the existing empty card', (tester) async {
    final repo = _ScriptedAddressRepository([
      Future.value(const Success(<Address>[])),
    ]);
    final cubit = AddressesCubit(repo);
    addTearDown(cubit.close);
    unawaited(cubit.load());

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();
    await tester.pump();

    expect(find.byType(EmptyAddressCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
