import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/address_codec.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/address.dart';
import '../domain/repositories/address_repository.dart';

final class LocalAddressRepository implements AddressRepository {
  LocalAddressRepository(this._preferences);
  final SharedPreferences _preferences;
  static const _key = 'saved_addresses_v1';
  @override
  Future<Result<List<Address>>> read() => Result.guard(() async {
        final raw = _preferences.getString(_key);
        if (raw == null) return <Address>[];
        final values =
            (jsonDecode(raw) as List).map((v) => v as Map<String, dynamic>);
        return values.map(AddressCodec.fromJson).toList();
      }, 'Unable to read saved addresses.');

  @override
  Future<Result<void>> save(List<Address> addresses) async {
    final result = await Result.guard(
      () async {
        final encoded = jsonEncode(addresses.map(AddressCodec.toJson).toList());
        return _preferences.setString(_key, encoded);
      },
      'Unable to save saved addresses.',
    );
    return result.when(
      success: (didPersist) => didPersist
          ? const Success(null)
          : const Failure(AppError('Unable to save saved addresses.')),
      failure: (error) => Failure(error),
    );
  }

  /// Removes the whole on-device address book.
  ///
  /// Deliberately on the local implementation only (not the domain
  /// contract): clearing is a device-lifecycle concern for sign-out and
  /// account deletion (audit S9), not part of the address-book API.
  Future<Result<void>> clear() => Result.guard<void>(
        () => _preferences.remove(_key),
        'Unable to clear saved addresses.',
      );
}
