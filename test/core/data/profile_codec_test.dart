import 'package:al_batal_elite/core/data/profile_codec.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Row-mapping tests moved from `test/core/entities/profile_test.dart`
/// (audit 2026-09-21, P1): the codec lives in `core/data` now, mirroring
/// the lib-side move of `Profile.fromRow`/`toProfileRow` into
/// [ProfileCodec]. The pure-entity tests (copyWith/equality) stay here.
void main() {
  group('ProfileCodec membership tier mapping', () {
    test('premium row maps to MembershipTier.premium', () {
      final p = ProfileCodec.fromRow({
        'id': 'u1',
        'full_name': 'Ahmed',
        'membership_tier': 'premium',
      });
      expect(p.tier, MembershipTier.premium);
    });

    test('missing column (pre-046 deployment) maps to standard', () {
      final p = ProfileCodec.fromRow({'id': 'u1', 'full_name': 'Ahmed'});
      expect(p.tier, MembershipTier.standard);
    });

    test('null and unexpected values map to standard, never crash', () {
      expect(ProfileCodec.fromRow({'id': 'u1', 'membership_tier': null}).tier,
          MembershipTier.standard);
      expect(ProfileCodec.fromRow({'id': 'u1', 'membership_tier': 'gold'}).tier,
          MembershipTier.standard);
    });

    test('toProfileRow excludes privileged columns', () {
      final row = ProfileCodec.toProfileRow(
        const Profile(id: 'u1', isAdmin: true),
      );
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

    test('mistyped columns degrade instead of throwing TypeError', () {
      final p = ProfileCodec.fromRow({
        'id': 'u1',
        'full_name': 123,
        'phone': 456,
        'is_admin': 'yes',
      });
      expect(p.fullName, '');
      expect(p.phone, isNull);
      expect(p.isAdmin, isFalse);
    });

    test('missing or mistyped id fails closed with FormatException', () {
      expect(() => ProfileCodec.fromRow({'full_name': 'Ahmed'}),
          throwsA(isA<FormatException>()));
      expect(() => ProfileCodec.fromRow({'id': 123, 'full_name': 'Ahmed'}),
          throwsA(isA<FormatException>()));
    });
  });

  group('Profile entity (pure domain)', () {
    test('copyWith preserves the tier; equality includes it', () {
      const premium = Profile(id: 'u1', tier: MembershipTier.premium);
      final renamed = premium.copyWith(fullName: 'Ahmed');
      expect(renamed.tier, MembershipTier.premium);
      expect(renamed, isNot(premium.copyWith(tier: MembershipTier.standard)));
    });
  });
}
