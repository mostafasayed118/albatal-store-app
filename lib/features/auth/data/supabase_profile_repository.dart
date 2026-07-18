import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/profile.dart';
import '../domain/repositories/profile_repository.dart';

/// Supabase-backed profile repository.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Profile?> readProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile(
      id: response['id'] as String,
      fullName: response['full_name'] as String? ?? '',
      phone: response['phone'] as String?,
      avatarUrl: response['avatar_url'] as String?,
      isAdmin: response['is_admin'] as bool? ?? false,
    );
  }

  @override
  Future<void> upsertProfile(Profile profile) async {
    await _client.from('profiles').upsert({
      'id': profile.id,
      'full_name': profile.fullName,
      'phone': profile.phone,
      'avatar_url': profile.avatarUrl,
    });
  }
}
