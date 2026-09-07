import 'package:equatable/equatable.dart';

/// Customer membership tier. Server-managed: only admins can change it
/// (migration 046 — `admin_set_membership_tier`), so the client treats it
/// as display data and never writes it through profile upserts.
enum MembershipTier { standard, premium }

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

  /// Maps a `profiles` row to a [Profile]. Tolerant of older deployments
  /// whose rows predate `membership_tier` (falls back to standard) and of
  /// unexpected values (standard, never a crash).
  factory Profile.fromRow(Map<String, dynamic> row) {
    final raw = row['membership_tier'] as String?;
    return Profile(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? '',
      phone: row['phone'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isAdmin: row['is_admin'] as bool? ?? false,
      tier: raw == 'premium' ? MembershipTier.premium : MembershipTier.standard,
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
