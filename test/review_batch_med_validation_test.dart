import 'package:al_batal_elite/core/utils/email_validator.dart';
import 'package:al_batal_elite/features/support/presentation/pages/support_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emailValidator (review-batch-med shared auth rule)', () {
    test('rejects null, empty, and @-less values', () {
      expect(emailValidator(null, invalidMessage: 'bad'), 'bad');
      expect(emailValidator('', invalidMessage: 'bad'), 'bad');
      expect(emailValidator('   ', invalidMessage: 'bad'), 'bad');
      expect(emailValidator('not-an-email', invalidMessage: 'bad'), 'bad');
    });

    test('accepts real addresses, ignoring surrounding whitespace', () {
      expect(emailValidator('user@example.com'), isNull);
      expect(emailValidator('  user@example.com  '), isNull);
    });

    test('falls back to English copy without a message', () {
      expect(emailValidator('nope'), isNotNull);
    });
  });

  group('isAllowedSupportLink (review-batch-med allowlist)', () {
    test('accepts https wa.me links', () {
      expect(isAllowedSupportLink(Uri.parse('https://wa.me/201154580512')),
          isTrue);
    });

    test('rejects non-https, foreign hosts, and exotic schemes', () {
      expect(isAllowedSupportLink(Uri.parse('http://wa.me/201154580512')),
          isFalse);
      expect(isAllowedSupportLink(Uri.parse('https://evil.com/wa.me/123')),
          isFalse);
      expect(isAllowedSupportLink(Uri.parse('javascript:alert(1)')), isFalse);
      expect(isAllowedSupportLink(Uri.parse('notaurl')), isFalse);
    });

    test('accepts mailto links', () {
      expect(
          isAllowedSupportLink(Uri.parse('mailto:al3tar66@gmail.com')), isTrue);
    });
  });
}
