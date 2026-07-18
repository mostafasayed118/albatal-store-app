import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/address.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/address_repository.dart';

/// Supabase-backed address repository.
class SupabaseAddressRepository implements AddressRepository {
  SupabaseAddressRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<Result<List<Address>>> read() async {
    try {
      final response = await _client
          .from('addresses')
          .select()
          .eq('user_id', _userId)
          .order('is_default', ascending: false);

      final addresses = (response as List).map((row) {
        return Address(
          id: row['id'] as String,
          recipient: row['recipient'] as String,
          line: row['line'] as String,
          city: row['city'] as String,
          country: row['country'] as String? ?? '',
          isDefault: row['is_default'] as bool? ?? false,
        );
      }).toList();

      return Success(addresses);
    } catch (e) {
      return Failure(AppError('Failed to load addresses: $e'));
    }
  }

  @override
  Future<Result<void>> save(List<Address> addresses) async {
    try {
      await _client.from('addresses').delete().eq('user_id', _userId);

      if (addresses.isNotEmpty) {
        final rows = addresses
            .map((a) => {
                  'user_id': _userId,
                  'recipient': a.recipient,
                  'line': a.line,
                  'city': a.city,
                  'country': a.country,
                  'is_default': a.isDefault,
                })
            .toList();
        await _client.from('addresses').insert(rows);
      }

      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to save addresses: $e'));
    }
  }
}
