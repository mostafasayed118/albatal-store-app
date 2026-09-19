import 'package:al_batal_elite/core/entities/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// [Money] owns the app's only money formatter — these pins are the
/// contract every price string in the UI and in generated documents
/// relies on.
void main() {
  group('Money.format (compact UI form)', () {
    test('whole major units print without decimals', () {
      expect(const Money(129000).format(), '1290 EGY');
      expect(const Money.egp(1290).format(), '1290 EGY');
      expect(Money.zero.format(), '0 EGY');
    });

    test('fractional piasters survive instead of truncating', () {
      // The cut-length regression: 399.50 EGP/m x 2.5 m = 99875 minor
      // units. `minorUnits ~/ 100` printed "998 EGY" — a pound below the
      // line_total the checkout payload submits for the same line.
      expect(const Money(99875).format(), '998.75 EGY');
      expect(const Money(1).format(), '0.01 EGY');
    });

    test('single-digit piasters are zero-padded', () {
      expect(const Money(505).format(), '5.05 EGY');
    });

    test('the symbol is overridable and stays outside the amount', () {
      expect(const Money(99875).format(symbol: 'USD'), '998.75 USD');
    });
  });

  group('Money.formatExact (document/table form)', () {
    test('always carries two decimals', () {
      expect(const Money.egp(1290).formatExact(), '1290.00 EGP');
      expect(const Money(99875).formatExact(), '998.75 EGP');
      expect(Money.zero.formatExact(), '0.00 EGP');
    });

    test('an empty symbol yields digits only, with no trailing space', () {
      expect(const Money(99875).formatExact(symbol: ''), '998.75');
      expect(const Money.egp(1290).formatExact(symbol: ''), '1290.00');
    });
  });
}
