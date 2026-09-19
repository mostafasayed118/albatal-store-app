import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/profile.dart';
import '../../../core/error/result.dart';

import '../domain/repositories/profile_repository.dart';

/// Supabase-backed profile repository.
///
/// Catches Supabase errors at this boundary so the Cubit only sees
/// [Result]. A missing profile row returns `Success(null)` (not a
/// failure) — the caller decides how to handle that case.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<Profile?>> readProfile(String userId) => Result.guard(
        () async {
          final response = await _client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

          if (response == null) return null;
          return Profile.fromRow(response);
        },
        'Failed to load profile',
      );

  @override
  Future<Result<void>> upsertProfile(Profile profile) => Result.guard<void>(
        () async {
          // toProfileRow() deliberately omits is_admin/membership_tier — the
          // tier is admin-managed (migration 046) and RLS pins privileged
          // columns to their existing values.
          await _client.from('profiles').upsert(profile.toProfileRow());
        },
        'Failed to save profile',
      );
}
