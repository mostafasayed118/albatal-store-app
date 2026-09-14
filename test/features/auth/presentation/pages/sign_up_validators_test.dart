import 'package:al_batal_elite/features/auth/presentation/pages/sign_up_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sign-up password complexity rule (audit 2026-09-14): min 8 chars plus
/// at least one letter and one digit. Sign-in / reset keep the length-only
/// [passwordValidator] so legacy credentials are not locked out.
void main() {
  group('passwordValidator (length-only, unchanged)', () {
    test('length floor still enforced', () {
      expect(passwordValidator('1234567'), isNotNull);
      expect(passwordValidator('12345678'), isNull);
      expect(passwordValidator('longenough'), isNull);
    });
  });

  group('signUpPasswordValidator (length + letter + digit)', () {
    test('rejects null and short values', () {
      expect(signUpPasswordValidator(null), isNotNull);
      expect(signUpPasswordValidator('a1b2c'), isNotNull);
    });

    test('rejects digit-only passwords of sufficient length', () {
      expect(signUpPasswordValidator('12345678'), isNotNull);
    });

    test('rejects letter-only passwords of sufficient length', () {
      expect(signUpPasswordValidator('longenough'), isNotNull);
    });

    test('rejects special-chars-only passwords of sufficient length', () {
      expect(signUpPasswordValidator('!!!!!!!!'), isNotNull);
    });

    test('accepts letter+digit passwords at the floor', () {
      expect(signUpPasswordValidator('abcdefg1'), isNull);
      expect(signUpPasswordValidator('1234567a'), isNull);
      expect(signUpPasswordValidator('Passw0rd!'), isNull);
    });

    test('carries localized copy through', () {
      expect(signUpPasswordValidator('short', tooShortMessage: 'قصير'), 'قصير');
      expect(signUpPasswordValidator('12345678', tooWeakMessage: 'ضعيفة'),
          'ضعيفة');
    });
  });
}
