import 'dart:convert';

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/data/local_address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_secure_store.dart';

void main() {
  test('constructs with the default secure store when none is injected', () {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance().then((prefs) {
      expect(LocalAddressRepository(prefs), isNotNull);
    });
  });

  test('a non-list cache shape degrades to an empty address book', () async {
    SharedPreferences.setMockInitialValues({
      'saved_addresses_v1': jsonEncode({'not': 'a list'}),
    });
    final prefs = await SharedPreferences.getInstance();
    final repo =
        LocalAddressRepository(prefs, secureStore: MemorySecureStore());

    final result = await repo.read();

    expect(result, isA<Success<List<Address>>>());
    expect((result as Success<List<Address>>).value, isEmpty);
  });

  test('a failing secured write surfaces as a Failure', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo =
        LocalAddressRepository(prefs, secureStore: ThrowingSecureStore());

    final result = await repo.save(const []);

    expect(result, isA<Failure<void>>());
  });
}
