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
}
