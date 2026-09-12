import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/services/secure_store.dart';
import '../../../core/data/address_codec.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../domain/address.dart';
import '../domain/repositories/address_repository.dart';

final class LocalAddressRepository implements ClearableAddressRepository {
  LocalAddressRepository(this._preferences, {SecureStore? secureStore})
      : _secureStore = secureStore ?? FlutterSecureStore();
  final SharedPreferences _preferences;

  /// Encrypted at-rest store for the address book (PII). The prefs
  /// handle is kept only for the one-time cleartext migration and for
  /// wiping the legacy key — all live reads/writes go to [_secureStore].
  final SecureStore _secureStore;
  static const _key = 'saved_addresses_v1';
  @override
  Future<Result<List<Address>>> read() => Result.guard(() async {
        final raw = await _readWithMigration();
        if (raw == null) return <Address>[];
        // Fail-soft on tampered cache: a corrupt payload yields an empty
        // book (logged) instead of a Failure — the address book is a
        // local convenience copy, never authoritative. Transport/secure-
        // store errors still propagate to [Result.guard] as failures.
        late final Object? decoded;
        try {
          decoded = jsonDecode(raw);
        } on FormatException catch (e) {
          Log.w('Saved addresses cache is corrupt; ignoring: $e');
          return <Address>[];
        }
        if (decoded is! List) {
          Log.w('Saved addresses cache has unexpected shape; ignoring.');
          return <Address>[];
        }
        final addresses = <Address>[];
        for (final entry in decoded) {
          final map = safeMap(entry);
          if (map.isEmpty) {
            Log.w('Skipping malformed address entry; ignoring.');
            continue;
          }
          final address = AddressCodec.fromJson(map);
          if (address.id.isEmpty) {
            Log.w('Skipping address entry with missing id; ignoring.');
            continue;
          }
          addresses.add(address);
        }
        return addresses;
      }, 'Unable to read saved addresses.');

  @override
  Future<Result<void>> save(List<Address> addresses) async {
    final result = await Result.guard(
      () async {
        final encoded = jsonEncode(addresses.map(AddressCodec.toJson).toList());
        return _secureStore.write(_key, encoded);
      },
      'Unable to save saved addresses.',
    );
    return result.when(
      success: (_) => const Success(null),
      failure: (error) => Failure(error),
    );
  }

  /// Removes the whole on-device address book.
  ///
  /// Implements [ClearableAddressRepository] (the domain wipe port) by
  /// delegating to [clear], which stays as the local-only API so the
  /// base address-book contract keeps no device-lifecycle methods.
  @override
  Future<Result<void>> clearAddresses() => clear();

  /// Removes the whole on-device address book.
  ///
  /// Deliberately on the local implementation only (not the base domain
  /// contract): clearing is a device-lifecycle concern for sign-out and
  /// account deletion (audit S9), not part of the address-book API.
  /// Wipes the encrypted entry AND the legacy cleartext prefs key so a
  /// pre-migration snapshot cannot survive the wipe.
  Future<Result<void>> clear() => Result.guard<void>(
        () async {
          await _secureStore.delete(_key);
          await _preferences.remove(_key);
        },
        'Unable to clear saved addresses.',
      );

  /// Reads the encrypted address book, migrating a cleartext legacy
  /// prefs entry once (write-to-secure then remove prefs) so upgrades
  /// keep the user's addresses without leaving PII in cleartext.
  Future<String?> _readWithMigration() async {
    final secured = await _secureStore.read(_key);
    if (secured != null) return secured;
    final legacy = _preferences.getString(_key);
    if (legacy == null) return null;
    await _secureStore.write(_key, legacy);
    await _preferences.remove(_key);
    return legacy;
  }
}
