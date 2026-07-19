import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/result.dart';

/// Abstraction for profile persistence.
///
/// Returns [Result] so callers receive errors at this boundary instead
/// of having to catch exceptions themselves.
abstract interface class ProfileRepository {
  /// Read the profile for [userId], or null if no profile row exists.
  Future<Result<Profile?>> readProfile(String userId);

  /// Insert or update [profile].
  Future<Result<void>> upsertProfile(Profile profile);
}
