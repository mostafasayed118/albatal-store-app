import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/addresses/presentation/pages/addresses_page.dart';
import 'package:al_batal_elite/features/addresses/presentation/widgets/address_form.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repo implements AddressRepository {
  _Repo({List<Address>? initial}) : addresses = [...?initial];

  final List<Address> addresses;
  Result<void> saveResult = const Success(null);
  List<Address>? lastSaved;

  @override
  Future<Result<List<Address>>> read() async => Success([...addresses]);

  @override
  Future<Result<void>> save(List<Address> next) async {
    lastSaved = [...next];
    if (saveResult is Success) {
      addresses
        ..clear()
        ..addAll(next);
    }
    return saveResult;
  }
}

const _home = Address(
  id: 'home',
  recipient: 'Home Owner',
  line: '1 Nile St',
  city: 'Cairo',
  country: 'EG',
  isDefault: true,
);
const _work = Address(
  id: 'work',
  recipient: 'Office',
  line: '2 Tahrir Sq',
  city: 'Cairo',
  country: 'EG',
);

void main() {
  group('AddressesCubit mutations', () {
    test('remove persists the filtered list', () async {
      final repo = _Repo(initial: [_home, _work]);
      final cubit = AddressesCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.remove(_work.id);

      expect(repo.lastSaved?.map((a) => a.id), ['home']);
      expect(cubit.state.addresses.single.id, 'home');
      expect(cubit.state.status, AddressesStatus.ready);
    });

    test('setDefault flips the flag on exactly one address', () async {
      final repo = _Repo(initial: [_home, _work]);
      final cubit = AddressesCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setDefault(_work.id);

      expect(repo.lastSaved?.where((a) => a.isDefault).single.id, 'work');
      expect(cubit.state.addresses.firstWhere((a) => a.id == 'work').isDefault,
          isTrue);
    });

    test('removing the default promotes the first remaining address', () async {
      final repo = _Repo(initial: [_home, _work]);
      final cubit = AddressesCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.remove(_home.id);

      expect(repo.lastSaved?.single.id, 'work');
      expect(repo.lastSaved?.single.isDefault, isTrue);
    });

    test('persist failure keeps the live book and surfaces coded error',
        () async {
      final repo = _Repo(initial: [_home]);
      repo.saveResult =
          const Failure<void>(AppError('disk', code: 'address_save_failed'));
      final cubit = AddressesCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setDefault('home');

      expect(cubit.state.status, AddressesStatus.failure);
      expect(cubit.state.addresses.single.id, 'home');
      expect(cubit.state.errorCode, 'address_save_failed');
    });
  });

  group('AddressesPage row menu', () {
    late _Repo repo;
    late AddressesCubit cubit;

    setUp(() async {
      repo = _Repo(initial: [_home, _work]);
      cubit = AddressesCubit(repo);
      await cubit.load();
    });

    tearDown(() => cubit.close());

    Widget harness() => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const AddressesPage(),
          ),
        );

    testWidgets('menu offers default, edit and delete actions', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Set as default'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();

      expect(repo.lastSaved?.where((a) => a.id == 'home').single.isDefault,
          isTrue);
    });

    testWidgets('delete action removes the row', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.lastSaved?.map((a) => a.id), ['home']);
      expect(find.text('Office'), findsNothing);
    });

    testWidgets('edit action opens the shared address form', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(AddressForm), findsOneWidget);
    });
  });
}
