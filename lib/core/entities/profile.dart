import 'package:equatable/equatable.dart';

import '../utils/safe_parse.dart';

/// Customer membership tier. Server-managed: only admins can change it
/// (migration 046 — `admin_set_membership_tier`), so the client treats it
/// as display data and never writes it through profile upserts.
enum MembershipTier { standard, premium }

/// Parses the server's tier string (`'standard' | 'premium'`) into the
/// typed enum, degrading to [MembershipTier.standard] for null or
/// unknown values — the same fail-soft contract as [Profile.fromRow].
/// One shared decoder so the admin detail page and profile reads agree
/// on what a tier string means instead of scattering `== 'premium'`.
MembershipTier membershipTierFromServerValue(String? raw) =>
    raw == 'premium' ? MembershipTier.premium : MembershipTier.standard;

/// Customer profile entity.
final class Profile extends Equatable {
  const Profile({
    required this.id,
    this.fullName = '',
    this.phone,
    this.avatarUrl,
    this.isAdmin = false,
    this.tier = MembershipTier.standard,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final bool isAdmin;
  final MembershipTier tier;

  Profile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    bool? isAdmin,
    MembershipTier? tier,
  }) =>
      Profile(
        id: id,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isAdmin: isAdmin ?? this.isAdmin,
        tier: tier ?? this.tier,
      );

  /// Maps a `profiles` row to a [Profile]. Total except for the identity:
  /// mistyped columns degrade to `''`/`null`/`false` via [safe_parse]
  /// (tolerant of older deployments whose rows predate `membership_tier`
  /// and of unexpected values — standard, never a crash), but a missing
  /// or mistyped `id` throws [FormatException] — an identity-less profile
  /// must fail closed at the repository boundary (`Result.guard` turns it
  /// into a `Failure`), never surface as a hollow `Success`.
  factory Profile.fromRow(Map<String, dynamic> row) {
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
  Map<String, dynamic> toProfileRow() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
      };

  @override
  List<Object?> get props => [id, fullName, phone, avatarUrl, isAdmin, tier];
}
