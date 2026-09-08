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
  Future<Result<List<Address>>> read() async {
    try {
      final raw = _preferences.getString(_key);
      if (raw == null) return const Success([]);
      final values =
          (jsonDecode(raw) as List).map((v) => v as Map<String, dynamic>);
      return Success(values.map(AddressCodec.fromJson).toList());
    } catch (error) {
      return Failure(AppError('Unable to read saved addresses.', cause: error));
    }
  }

  @override
  Future<Result<void>> save(List<Address> addresses) async {
    try {
      final encoded = jsonEncode(addresses.map(AddressCodec.toJson).toList());
      return await _preferences.setString(_key, encoded)
          ? const Success(null)
          : const Failure(AppError('Unable to save saved addresses.'));
    } catch (error) {
      return Failure(AppError('Unable to save saved addresses.', cause: error));
    }
  }

  /// Removes the whole on-device address book.
  ///
  /// Deliberately on the local implementation only (not the domain
  /// contract): clearing is a device-lifecycle concern for sign-out and
  /// account deletion (audit S9), not part of the address-book API.
  Future<Result<void>> clear() async {
    try {
      await _preferences.remove(_key);
      return const Success(null);
    } catch (error) {
      return Failure(
          AppError('Unable to clear saved addresses.', cause: error));
    }
  }
}
