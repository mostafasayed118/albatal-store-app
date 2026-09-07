import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile membership tier mapping', () {
    test('premium row maps to MembershipTier.premium', () {
      final p = Profile.fromRow({
        'id': 'u1',
        'full_name': 'Ahmed',
        'membership_tier': 'premium',
      });
      expect(p.tier, MembershipTier.premium);
    });

    test('missing column (pre-046 deployment) maps to standard', () {
      final p = Profile.fromRow({'id': 'u1', 'full_name': 'Ahmed'});
      expect(p.tier, MembershipTier.standard);
    });

    test('null and unexpected values map to standard, never crash', () {
      expect(Profile.fromRow({'id': 'u1', 'membership_tier': null}).tier,
          MembershipTier.standard);
      expect(Profile.fromRow({'id': 'u1', 'membership_tier': 'gold'}).tier,
          MembershipTier.standard);
    });

    test('toProfileRow excludes privileged columns', () {
      final row = const Profile(id: 'u1', isAdmin: true).toProfileRow();
      expect(row.containsKey('is_admin'), isFalse,
          reason: 'the self-upsert payload must never carry is_admin');
      expect(row.containsKey('membership_tier'), isFalse,
          reason: 'the tier is admin-managed (migration 046); sending it '
              'would fail RLS or be silently pinned');
      expect(row['id'], 'u1');
      expect(row.containsKey('full_name'), isTrue);
      expect(row.containsKey('phone'), isTrue);
      expect(row.containsKey('avatar_url'), isTrue);
    });

    test('copyWith preserves the tier; equality includes it', () {
      const premium = Profile(id: 'u1', tier: MembershipTier.premium);
      final renamed = premium.copyWith(fullName: 'Ahmed');
      expect(renamed.tier, MembershipTier.premium);
      expect(renamed, isNot(premium.copyWith(tier: MembershipTier.standard)));
    });
  });
}
