import 'package:al_batal_elite/core/entities/profile.dart';

/// Abstraction for profile persistence.
abstract interface class ProfileRepository {
  Future<Profile?> readProfile(String userId);
  Future<void> upsertProfile(Profile profile);
}
