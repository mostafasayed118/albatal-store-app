import 'package:equatable/equatable.dart';

/// Customer membership tier. Server-managed: only admins can change it
/// (migration 046 — `admin_set_membership_tier`), so the client treats it
/// as display data and never writes it through profile upserts.
enum MembershipTier { standard, premium }

/// Parses the server's tier string (`'standard' | 'premium'`) into the
/// typed enum, degrading to [MembershipTier.standard] for null or
/// unknown values — the same fail-soft contract as [ProfileCodec.fromRow].
/// One shared decoder so the admin detail page and profile reads agree
/// on what a tier string means instead of scattering `== 'premium'`.
MembershipTier membershipTierFromServerValue(String? raw) =>
    raw == 'premium' ? MembershipTier.premium : MembershipTier.standard;

/// Customer profile entity.
///
/// Row mapping lives in `core/data/profile_codec.dart` (audit 2026-09-21,
/// P1): the entity stays a pure domain model with no DB-map knowledge, so
/// a client write can never accidentally include privileged columns.
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

  @override
  List<Object?> get props => [id, fullName, phone, avatarUrl, isAdmin, tier];
}
