import 'package:equatable/equatable.dart';

/// Customer membership tier. Server-managed: only admins can change it
/// (migration 046 — `admin_set_membership_tier`), so the client treats it
/// as display data and never writes it through profile upserts.
///
/// `wholesale` (migration 078) is the B2B tier: admins assign it, and the
/// server resolves negotiated list prices for wholesale members
/// (`wholesale_price_lists`). Never send it through self-service writes —
/// RLS pins privileged columns either way.
enum MembershipTier { standard, premium, wholesale }

/// Parses the server's tier string (`'standard' | 'premium' | 'wholesale'`)
/// into the typed enum, degrading to [MembershipTier.standard] for null or
/// unknown values — the same fail-soft contract as the row codec.
/// One shared decoder so the admin detail page and profile reads agree
/// on what a tier string means instead of scattering `== 'premium'`.
MembershipTier membershipTierFromServerValue(String? raw) {
  switch (raw) {
    case 'premium':
      return MembershipTier.premium;
    case 'wholesale':
      return MembershipTier.wholesale;
    default:
      return MembershipTier.standard;
  }
}

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

  @override
  List<Object?> get props => [id, fullName, phone, avatarUrl, isAdmin, tier];
}
