import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the audit follow-up keys: every user-facing string that was
/// hardcoded in English must resolve in both locales.
void main() {
  group('audit follow-up l10n keys', () {
    test('server-confirmed totals header', () {
      expect(AppLocalizationsEn().serverConfirmedTotals,
          'Server-confirmed totals');
      expect(AppLocalizationsAr().serverConfirmedTotals.isNotEmpty, isTrue);
    });

    test('payment blocking errors', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.orderReferenceMissing,
          'Unable to continue: the order reference is missing.');
      expect(en.customerEmailMissing,
          'Unable to continue: the customer email is missing. Please sign in again.');
      expect(en.paymentLinkInvalid,
          'The payment checkout link is invalid. Please retry.');
      expect(en.paymentSucceededNoReference,
          'Payment succeeded but the order reference is missing.');
      for (final value in [
        ar.orderReferenceMissing,
        ar.customerEmailMissing,
        ar.paymentLinkInvalid,
        ar.paymentSucceededNoReference,
      ]) {
        expect(value.isNotEmpty, isTrue);
      }
    });

    test('payment retry messages', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.paymentCancelledRetry, 'Payment cancelled. You can retry.');
      expect(en.paymentExpiredRetry, 'Payment expired. You can retry.');
      expect(
          en.paymentTimedOutRetry,
          'Payment verification timed out. '
          'Please check your orders before retrying.');
      expect(en.paymentFailedRetry, 'Payment failed. You can retry.');
      for (final value in [
        ar.paymentCancelledRetry,
        ar.paymentExpiredRetry,
        ar.paymentTimedOutRetry,
        ar.paymentFailedRetry,
      ]) {
        expect(value.isNotEmpty, isTrue);
      }
    });

    test('admin access message', () {
      expect(AppLocalizationsEn().adminAccessRequired, 'Admin access required');
      expect(AppLocalizationsAr().adminAccessRequired.isNotEmpty, isTrue);
    });
  });
}
