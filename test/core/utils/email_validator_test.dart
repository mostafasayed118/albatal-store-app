import 'package:al_batal_elite/core/utils/email_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// RFC-5322-lite rule (audit 2026-09-14): local@domain with an alphabetic
/// TLD required, 64-char local cap, 254-char total cap. Pragmatic on
/// purpose — the goal is to match what Supabase accepts, not full RFC.
void main() {
  group('emailValidator (RFC-5322-lite, audit 2026-09-14)', () {
    test('rejects null, empty, and whitespace-only values', () {
      expect(emailValidator(null, invalidMessage: 'bad'), 'bad');
      expect(emailValidator('', invalidMessage: 'bad'), 'bad');
      expect(emailValidator('   ', invalidMessage: 'bad'), 'bad');
    });

    test('rejects the old contains-@ false positives', () {
      expect(emailValidator('@'), isNotNull);
      expect(emailValidator('a@b'), isNotNull);
      expect(emailValidator('not-an-email'), isNotNull);
      expect(emailValidator('nope'), isNotNull);
    });

    test('rejects malformed structure', () {
      expect(emailValidator('a@@b.com'), isNotNull);
      expect(emailValidator('user@.com'), isNotNull);
      expect(emailValidator('user@domain.'), isNotNull);
      expect(emailValidator('user@domain..com'), isNotNull);
      expect(emailValidator('.user@example.com'), isNotNull);
      expect(emailValidator('user.@example.com'), isNotNull);
      expect(emailValidator('user name@example.com'), isNotNull);
      expect(emailValidator('user@-example.com'), isNotNull);
      expect(emailValidator('user@example.c'), isNotNull); // 1-char TLD
      expect(emailValidator('userexample.com'), isNotNull);
      expect(emailValidator('user@example..com'), isNotNull);
    });

    test('accepts real addresses', () {
      expect(emailValidator('user@example.com'), isNull);
      expect(emailValidator('user.name@example.com'), isNull);
      expect(emailValidator('user+tag@example.co.uk'), isNull);
      expect(emailValidator('user_name@sub.example-mail.io'), isNull);
      expect(emailValidator("o'brien@example.com"), isNull);
      expect(emailValidator('a@b.co'), isNull);
    });

    test('accepts surrounding whitespace (trimmed)', () {
      expect(emailValidator('  user@example.com  '), isNull);
    });

    test('enforces length caps', () {
      final longLocal = '${'a' * 65}@example.com';
      final longTotal = 'user@${'d' * 250}.com';
      expect(emailValidator(longLocal), isNotNull);
      expect(emailValidator(longTotal), isNotNull);
      // At the cap boundaries, still valid ('@' counts toward 254; DNS
      // labels stay within their own 63-char cap).
      expect(emailValidator('${'a' * 64}@example.com'), isNull);
      final atTotalCap =
          'user@${'d' * 63}.${'d' * 63}.${'d' * 63}.${'c' * 57}';
      expect(atTotalCap.length, 254);
      expect(emailValidator(atTotalCap), isNull);
    });

    test('falls back to English copy without a message', () {
      expect(emailValidator('nope'), 'Please enter a valid email');
    });
  });
}
