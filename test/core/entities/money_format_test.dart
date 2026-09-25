import 'package:al_batal_elite/core/entities/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// [Money] owns the app's locale-agnostic money formatter — these pins are
/// the contract the generated documents (invoices, admin tables) and the
/// non-UI composition rely on.
///
/// Shopper-facing prices do NOT use [Money.format]: they go through
/// `moneyText()` in `shared/l10n/money_copy.dart`, which localizes the
/// digits, the grouping and the symbol (audit UX-019). Both paths agree on
/// the ISO 4217 code `EGP`; the legacy `EGY` label (an ISO 3166 country
/// code, never a currency) was removed from the default in the same change.
void main() {
  group('Money.format (compact, locale-agnostic)', () {
    test('whole major units print without decimals', () {
      expect(const Money(129000).format(), '1290 EGP');
      expect(const Money.egp(1290).format(), '1290 EGP');
      expect(Money.zero.format(), '0 EGP');
    });

    test('fractional piasters survive instead of truncating', () {
      // The cut-length regression: 399.50 EGP/m x 2.5 m = 99875 minor
      // units. `minorUnits ~/ 100` printed "998 EGP" — a pound below the
      // line_total the checkout payload submits for the same line.
      expect(const Money(99875).format(), '998.75 EGP');
      expect(const Money(1).format(), '0.01 EGP');
    });

    test('single-digit piasters are zero-padded', () {
      expect(const Money(505).format(), '5.05 EGP');
    });

    test('the symbol is overridable and stays outside the amount', () {
      expect(const Money(99875).format(symbol: 'USD'), '998.75 USD');
    });
  });

  group('Money.tryParseMajor', () {
    test('parses whole and fractional major units exactly', () {
      expect(Money.tryParseMajor('1890'), const Money(189000));
      expect(Money.tryParseMajor(' 12.5 '), const Money(1250));
      expect(Money.tryParseMajor('12.50'), const Money(1250));
      expect(Money.tryParseMajor('0.01'), const Money(1));
    });

    test('rejects ambiguous or lossy input instead of rounding', () {
      expect(Money.tryParseMajor(''), isNull);
      expect(Money.tryParseMajor('-1'), isNull);
      expect(Money.tryParseMajor('1.234'), isNull);
      expect(Money.tryParseMajor('1e2'), isNull);
      expect(Money.tryParseMajor('1,290'), isNull);
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
