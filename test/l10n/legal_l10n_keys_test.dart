import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four legal pages used to render a single placeholder sentence each.
/// These pins guard the real copy, its Arabic mirror, and the last-updated
/// line the pages display above the content.
void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  // (key, English copy, Arabic copy, English section markers)
  final documents = <(String, String, String, List<String>)>[
    (
      'privacyPolicyContent',
      en.privacyPolicyContent,
      ar.privacyPolicyContent,
      ['What we collect', 'Supabase', 'Paymob', 'OneSignal', 'Settings'],
    ),
    (
      'termsOfServiceContent',
      en.termsOfServiceContent,
      ar.termsOfServiceContent,
      ['Your account', 'Payment', 'Governing law', 'Egypt'],
    ),
    (
      'shippingPolicyContent',
      en.shippingPolicyContent,
      ar.shippingPolicyContent,
      ['Delivery areas', 'Processing time', 'Failed delivery'],
    ),
    (
      'returnsPolicyContent',
      en.returnsPolicyContent,
      ar.returnsPolicyContent,
      ['14-day window', 'Exclusions', 'Refunds'],
    ),
  ];

  test('every legal document carries real English sections', () {
    for (final (key, english, _, markers) in documents) {
      expect(english, isNot(contains('will be added')), reason: key);
      expect(english, contains('\n\n'),
          reason: '$key must use blank-line section breaks');
      for (final marker in markers) {
        expect(english, contains(marker), reason: '$key is missing "$marker"');
      }
    }
  });

  test('every legal document is translated into Arabic', () {
    for (final (key, english, arabic, _) in documents) {
      expect(arabic, isNot(equals(english)),
          reason: '$key is still English in Arabic');
      expect(arabic, isNot(contains('will be added')), reason: key);
      expect(arabic, contains('\n\n'),
          reason: '$key must use blank-line section breaks');
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(arabic), isTrue,
          reason: '$key has no Arabic script');
    }
  });

  test('last-updated line is pinned in both locales', () {
    expect(en.legalLastUpdated, 'Last updated: 24 October 2026');
    expect(ar.legalLastUpdated, 'آخر تحديث: 24 أكتوبر 2026');
  });
}
