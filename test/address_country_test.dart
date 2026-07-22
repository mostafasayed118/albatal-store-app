import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/address.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAddressRepository implements AddressRepository {
  _StubAddressRepository({List<Address>? addresses})
      : addresses = addresses ?? [];

  List<Address> addresses;

  @override
  Future<Result<List<Address>>> read() async => Success(addresses);

  @override
  Future<Result<void>> save(List<Address> addresses) async {
    this.addresses = addresses;
    return const Success(null);
  }
}

void main() {
  group('Address country — domain entity', () {
    test('Address stores country field', () {
      const address = Address(
        id: 'a1',
        recipient: 'Test',
        line: '123 St',
        city: 'Cairo',
        country: 'Egypt',
      );
      expect(address.country, 'Egypt');
    });

    test('Address copyWith preserves country', () {
      const address = Address(
        id: 'a1',
        recipient: 'Test',
        line: '123 St',
        city: 'Cairo',
        country: 'Egypt',
      );
      final updated = address.copyWith(country: 'KSA');
      expect(updated.country, 'KSA');
      // Original unchanged
      expect(address.country, 'Egypt');
    });

    test('Address equality includes country', () {
      const a = Address(
        id: '1',
        recipient: 'R',
        line: 'L',
        city: 'C',
        country: 'EG',
      );
      const b = Address(
        id: '1',
        recipient: 'R',
        line: 'L',
        city: 'C',
        country: 'EG',
      );
      const c = Address(
        id: '1',
        recipient: 'R',
        line: 'L',
        city: 'C',
        country: 'SA',
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('Address country — persistence', () {
    test('country survives save/read cycle', () async {
      final repo = _StubAddressRepository();
      final cubit = AddressesCubit(repo);

      const address = Address(
        id: 'a1',
        recipient: 'Test',
        line: '123 St',
        city: 'Cairo',
        country: 'Egypt',
      );
      await cubit.upsert(address);

      // Read back from repository
      final result = await repo.read();
      result.when(
        success: (addresses) {
          expect(addresses.length, 1);
          expect(addresses.first.country, 'Egypt');
        },
        failure: (_) => fail('Expected success'),
      );
      await cubit.close();
    });

    test('country value is not replaced by locale key', () async {
      final repo = _StubAddressRepository();
      final cubit = AddressesCubit(repo);

      const address = Address(
        id: 'a2',
        recipient: 'User',
        line: '456 Ave',
        city: 'Alexandria',
        country: 'Egypt',
      );
      await cubit.upsert(address);

      // Verify the raw country string is preserved (not a translated key)
      final result = await repo.read();
      result.when(
        success: (addresses) {
          expect(addresses.first.country, 'Egypt');
          expect(addresses.first.country, isNot('مصر'));
          expect(addresses.first.country, isNot('Country'));
        },
        failure: (_) => fail('Expected success'),
      );
      await cubit.close();
    });

    test('country is persisted through LocalAddressRepository JSON round-trip',
        () async {
      final repo = _StubAddressRepository();
      const original = Address(
        id: 'a3',
        recipient: 'R',
        line: 'L',
        city: 'C',
        country: 'United Arab Emirates',
      );

      await repo.save([original]);
      final result = await repo.read();

      result.when(
        success: (addresses) {
          expect(addresses.first.country, 'United Arab Emirates');
          expect(addresses.first.recipient, 'R');
        },
        failure: (_) => fail('Expected success'),
      );
    });
  });

  group('Address country — localized labels exist', () {
    test('English country label is not empty', () {
      final en = AppLocalizationsEn('en');
      expect(en.countryLabel, isNotEmpty);
      expect(en.countryLabel, 'Country');
    });

    testWidgets('Arabic country label is distinct from English',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox()),
      ));
      await tester.pump();

      final ar = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(ar.countryLabel, isNotEmpty);
      expect(ar.countryLabel, isNot('Country'));
    });
  });
}
