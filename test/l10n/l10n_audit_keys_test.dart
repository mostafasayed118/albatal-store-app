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

    test('instapay session-missing body (audit 2026-09-13)', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.instapaySessionMissing, 'Payment session not found');
      expect(ar.instapaySessionMissing.isNotEmpty, isTrue);
    });

    test('order-notification opt-in tile (audit 2026-09-13)', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.orderNotifications, 'Order notifications');
      expect(en.orderNotificationsSubtitle, 'Confirmations and status updates');
      for (final value in [
        ar.orderNotifications,
        ar.orderNotificationsSubtitle,
      ]) {
        expect(value.isNotEmpty, isTrue);
      }
    });

    test('address surfaces labels and validators', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.streetAddress, 'Street address');
      expect(en.city, 'City');
      expect(en.country, 'Country');
      expect(en.recipientName, 'Recipient');
      expect(en.streetAddressRequired, 'Enter a valid street address');
      expect(en.cityRequired, 'City is required');
      expect(en.countryRequired, 'Country is required');
      expect(en.editAddress, 'Edit address');
      expect(en.save, 'Save');
      for (final value in [
        ar.streetAddress,
        ar.city,
        ar.country,
        ar.recipientName,
        ar.streetAddressRequired,
        ar.cityRequired,
        ar.countryRequired,
        ar.editAddress,
        ar.save,
      ]) {
        expect(value.isNotEmpty, isTrue);
      }
    });
    test('inline review list Show-all label (audit 2026-09-19 #4)', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.showAllReviews(3), 'Show all (3)');
      expect(ar.showAllReviews(3), isNotEmpty);
      // The defect this key closes was an Arabic shopper reading English, so
      // the assertion that matters is difference, not non-emptiness.
      expect(ar.showAllReviews(3), isNot(en.showAllReviews(3)));
      // ...and the count the button promises must survive translation.
      expect(ar.showAllReviews(3), contains('3'));
      expect(ar.showAllReviews(11), contains('11'));
    });

    test('offline banner copy', () {
      expect(
          AppLocalizationsEn().offlineBannerMessage, 'No internet connection');
      expect(AppLocalizationsAr().offlineBannerMessage.isNotEmpty, isTrue);
    });
  });
}
