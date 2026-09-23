import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:al_batal_elite/shared/l10n/money_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the audit UX-019 contract: a shopper price carries the ISO 4217
/// code (EGP — not the legacy 'EGY' country-code label) and the reader's
/// own digits, grouping and currency symbol.
void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  group('moneyText (EN)', () {
    test('uses the ISO 4217 code and thousands grouping', () {
      expect(moneyText(en, const Money.egp(1290)), '1,290 EGP');
    });

    test('drops decimals for whole amounts', () {
      expect(moneyText(en, Money.zero), '0 EGP');
      expect(moneyText(en, const Money.egp(850)), '850 EGP');
    });

    test('keeps the two decimals of fractional piasters', () {
      // The cut-length regression: 399.50 EGP/m × 2.5 m = 99875 minor
      // units; truncating would show a pound less than the order records.
      expect(moneyText(en, const Money(99875)), '998.75 EGP');
      expect(moneyText(en, const Money(1)), '0.01 EGP');
    });
  });

  group('moneyText (AR)', () {
    test('renders Arabic-Indic digits and the Arabic pound symbol', () {
      // ar_EG number data: digits ٠-٩, group separator ٬, symbol ج.م.
      expect(moneyText(ar, const Money.egp(1290)), '١٬٢٩٠ ج.م.');
    });

    test('keeps the same decimal rule in Arabic', () {
      expect(moneyText(ar, const Money(99875)), '٩٩٨٫٧٥ ج.م.');
      expect(moneyText(ar, Money.zero), '٠ ج.م.');
    });
  });

  group('moneyText — the legacy label is gone', () {
    test('no locale renders the non-ISO "EGY" label', () {
      for (final text in [
        moneyText(en, const Money.egp(1290)),
        moneyText(ar, const Money.egp(1290)),
      ]) {
        expect(text.contains('EGY'), isFalse,
            reason: 'EGY is the ISO 3166 country code, not a currency');
      }
    });

    test('the currency symbol comes from the ARB, not the entity default', () {
      // Money.format() is the locale-agnostic path; moneyText() is the
      // shopper path. Both must now agree on EGP for English.
      expect(moneyText(en, const Money.egp(5)), contains('EGP'));
      expect(const Money.egp(5).format(), '5 EGP');
    });
  });
}
