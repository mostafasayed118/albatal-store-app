import 'package:al_batal_elite/core/entities/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.format (audit 2026-09-14 piaster fix)', () {
    test('whole amounts keep the established whole-EGY style', () {
      expect(const Money(129000).format(), '1290 EGY');
      expect(const Money.egp(75).format(), '75 EGY');
      expect(Money.zero.format(), '0 EGY');
    });

    test('piasters render instead of being truncated', () {
      expect(const Money(129050).format(), '1290.50 EGY');
      expect(const Money(129005).format(), '1290.05 EGY');
      expect(const Money(50).format(), '0.50 EGY');
      expect(const Money(5).format(), '0.05 EGY');
    });

    test('empty symbol yields the bare major-unit number', () {
      expect(const Money(129000).format(symbol: ''), '1290');
      expect(const Money(129050).format(symbol: ''), '1290.50');
    });
  });

  group('Money.tryParseMajor (audit 2026-09-14 conversion point)', () {
    test('parses EGP text into exact minor units', () {
      expect(Money.tryParseMajor('1290'), const Money(129000));
      expect(Money.tryParseMajor('1290.5'), const Money(129050));
      expect(Money.tryParseMajor('1290.50'), const Money(129050));
      expect(Money.tryParseMajor('0.05'), const Money(5));
      expect(Money.tryParseMajor(' 450 '), const Money(45000));
      expect(Money.tryParseMajor('1290.'), const Money(129000));
      expect(Money.tryParseMajor('.5'), const Money(50));
    });

    test('rejects blank, malformed, negative, and over-precise input', () {
      expect(Money.tryParseMajor(''), isNull);
      expect(Money.tryParseMajor('   '), isNull);
      expect(Money.tryParseMajor('abc'), isNull);
      expect(Money.tryParseMajor('1290.50.5'), isNull);
      expect(Money.tryParseMajor('-50'), isNull);
      expect(Money.tryParseMajor('1.999'), isNull);
    });

    test('parsed value equals the Money constructed from minor units', () {
      expect(Money.tryParseMajor('1290.50'), const Money(129050));
      expect(
        Money.tryParseMajor('1290.50'),
        Money.tryParseMajor('1290.5'),
      );
    });
  });
}
