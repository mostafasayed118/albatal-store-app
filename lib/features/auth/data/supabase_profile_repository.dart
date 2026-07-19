import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';

import '../domain/repositories/profile_repository.dart';

/// Supabase-backed profile repository.
///
/// Catches Supabase errors at this boundary so the Cubit only sees
/// [Result]. A missing profile row returns `Success(null)` (not a
/// failure) — the caller decides how to handle that case.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<Profile?>> readProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return const Success(null);
      return Success(Profile(
        id: response['id'] as String,
        fullName: response['full_name'] as String? ?? '',
        phone: response['phone'] as String?,
        avatarUrl: response['avatar_url'] as String?,
        isAdmin: response['is_admin'] as bool? ?? false,
      ));
    } catch (e) {
      return Failure(AppError('Failed to load profile', cause: e));
    }
  }

  @override
  Future<Result<void>> upsertProfile(Profile profile) async {
    try {
      await _client.from('profiles').upsert({
        'id': profile.id,
        'full_name': profile.fullName,
        'phone': profile.phone,
        'avatar_url': profile.avatarUrl,
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to save profile', cause: e));
    }
  }
}
