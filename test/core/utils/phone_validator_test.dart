import 'package:al_batal_elite/core/utils/phone_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phoneValidator', () {
    test('accepts the canonical 11-digit local form', () {
      expect(phoneValidator('01012345678'), isNull);
    });

    test('accepts every allocated Egyptian mobile prefix', () {
      expect(phoneValidator('01012345678'), isNull); // Orange
      expect(phoneValidator('01112345678'), isNull); // Vodafone
      expect(phoneValidator('01212345678'), isNull); // Etisalat
      expect(phoneValidator('01512345678'), isNull); // WE
    });

    test('accepts the 10-digit national form without the leading zero', () {
      expect(phoneValidator('1012345678'), isNull);
    });

    test('accepts the Egypt country code in its three spellings', () {
      expect(phoneValidator('+201012345678'), isNull);
      expect(phoneValidator('00201012345678'), isNull);
      expect(phoneValidator('201012345678'), isNull);
      // Country code followed by the zeroed national form also resolves.
      expect(phoneValidator('+2001012345678'), isNull);
    });

    test('accepts the separators people actually type', () {
      expect(phoneValidator('010 1234 5678'), isNull);
      expect(phoneValidator('010-1234-5678'), isNull);
      expect(phoneValidator('(010) 1234 5678'), isNull);
      expect(phoneValidator(' 01012345678 '), isNull);
      expect(phoneValidator('+20 101 234 5678'), isNull);
    });

    test('rejects non-mobile prefixes (unallocated and landline)', () {
      // 013/014 are not allocated to Egyptian mobile operators.
      expect(phoneValidator('01312345678'), isNotNull);
      expect(phoneValidator('01412345678'), isNotNull);
      // Cairo landline shape.
      expect(phoneValidator('0223333333'), isNotNull);
    });

    test('rejects wrong digit counts', () {
      expect(phoneValidator('0101234567'), isNotNull); // one digit short
      expect(phoneValidator('010123456789'), isNotNull); // one digit long
      expect(phoneValidator('101234567'), isNotNull); // 9 national digits
    });

    test('rejects letters, symbols and empty input', () {
      expect(phoneValidator('call me'), isNotNull);
      expect(phoneValidator('01012345678x'), isNotNull);
      expect(phoneValidator(''), isNotNull);
      expect(phoneValidator('   '), isNotNull);
      expect(phoneValidator(null), isNotNull);
    });

    test('returns the passed localized message on failure', () {
      expect(
        phoneValidator('nope', invalidMessage: 'رقم غير صالح'),
        'رقم غير صالح',
      );
    });

    test('returns null when valid, same contract as emailValidator', () {
      expect(phoneValidator('01112345678', invalidMessage: 'x'), isNull);
    });
  });
}
