import '../entities/profile.dart';
import '../utils/safe_parse.dart';

/// Row codec for the `profiles` table.
///
/// Lives in the data layer (audit 2026-09-21, P1): hand-written DB maps do
/// not belong on the domain entity — same convention as [AddressCodec] and
/// `ProductCodec`. The privileged-column rule below is the security
/// invariant that justifies a single owner.
abstract final class ProfileCodec {
  /// Maps a `profiles` row to a [Profile]. Total except for the identity:
  /// mistyped columns degrade to `''`/`null`/`false` via [safe_parse]
  /// (tolerant of older deployments whose rows predate `membership_tier`
  /// and of unexpected values — standard, never a crash), but a missing
  /// or mistyped `id` throws [FormatException] — an identity-less profile
  /// must fail closed at the repository boundary (`Result.guard` turns it
  /// into a `Failure`), never surface as a hollow `Success`.
  static Profile fromRow(Map<String, dynamic> row) {
    final id = safeString(row, 'id');
    if (id.isEmpty) {
      throw const FormatException('Profile row has no usable id');
    }
    return Profile(
      id: id,
      fullName: safeString(row, 'full_name'),
      phone: optString(row, 'phone'),
      avatarUrl: optString(row, 'avatar_url'),
      isAdmin: safeBool(row, 'is_admin'),
      tier: membershipTierFromServerValue(optString(row, 'membership_tier')),
    );
  }

  /// Columns a customer may write through the self-upsert path
  /// (`upsertProfile`). Deliberately EXCLUDES `is_admin` and
  /// `membership_tier`: RLS (migration 046) pins both to the existing
  /// row's values, so sending them would either fail the write or be
  /// ignored — the client never claims privileges it does not have.
  static Map<String, dynamic> toProfileRow(Profile profile) => {
        'id': profile.id,
        'full_name': profile.fullName,
        'phone': profile.phone,
        'avatar_url': profile.avatarUrl,
      };
}
