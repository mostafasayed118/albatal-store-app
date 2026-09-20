import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:al_batal_elite/shared/l10n/failure_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-19, sweep part 32: app-authored failure copy must never reach a
/// shopper in English, and server-authored prose must never be replaced.
///
/// The two properties are pinned separately because they fail in opposite
/// directions: a missing mapping leaks English, and an over-eager mapper would
/// swallow a server message the P1 ruling says to show verbatim.
const _expectedEn = {
  kFailureLoad: "Couldn't load. Please try again.",
  kFailureSave: "Couldn't save. Please try again.",
  kFailureNetwork: 'Connection problem. Please try again.',
  kFailureNotAuthenticated: 'Please sign in again.',
  kFailureSessionExpired: 'Your session expired. Please sign in again.',
  kFailureSignInFailed: 'Sign-in failed. Please try again.',
  kFailureSignUpFailed: 'Sign-up failed. Please try again.',
  kFailureNotFound: "We couldn't find that.",
  kFailureUnexpected: 'Something went wrong. Please try again.',
  kAuthInvalidCredentials: 'Invalid email or password',
  kAuthEmailUnconfirmed: 'Please verify your email address first',
  kAuthEmailInUse: 'An account with this email already exists',
  kAuthWeakPassword: 'Password must be at least 8 characters',
  kDeleteEmailMismatch: 'The email does not match this account',
  kDeleteAdminBlocked: 'Admin accounts cannot be deleted in the app',
  kDeleteNotOwner: 'You can only delete your own account',
  kDeleteFailed: 'Account deletion failed. Please try again.',
  // Admin codes (Tier 3b): the admin console is fully localized by owner
  // decision (part 34), so its failures must resolve here like every other
  // app-authored code.
  kAdminAccessDenied: 'Access denied: admin only',
  kAdminOrdersLoadFailed: "Couldn't load orders. Please try again.",
  kAdminOrderLoadFailed: "Couldn't load this order. Please try again.",
  kAdminOrderNotFound: 'Order not found',
  kAdminOrderStatusInvalid: "That order status isn't recognized.",
  kAdminOrderStatusUpdateFailed:
      "Couldn't update the order status. Please try again.",
  kAdminLowStockLoadFailed:
      "Couldn't load low-stock products. Please try again.",
  kAdminSalesLoadFailed: "Couldn't load sales data. Please try again.",
  kAdminStockUpdateFailed: "Couldn't update the stock. Please try again.",
  kAdminProductsLoadFailed: "Couldn't load products. Please try again.",
  kAdminProductLoadFailed: "Couldn't load this product. Please try again.",
  kAdminCategoriesLoadFailed: "Couldn't load categories. Please try again.",
  kAdminProductSaveFailed: "Couldn't save the product. Please try again.",
  kAdminVariantSaveFailed: "Couldn't save the variant. Please try again.",
  kAdminImagesSaveFailed: "Couldn't save the images. Please try again.",
  kAdminVariantsLoadFailed: "Couldn't load variants. Please try again.",
  kAdminImagesLoadFailed: "Couldn't load images. Please try again.",
  kAdminMembershipUpdateFailed:
      "Couldn't update the membership tier. Please try again.",
  kAdminCouponsLoadFailed: "Couldn't load coupons. Please try again.",
  kAdminCouponCreateFailed: "Couldn't create the coupon. Please try again.",
  kAdminCouponUpdateFailed: "Couldn't update the coupon. Please try again.",
  kAdminCustomersLoadFailed: "Couldn't load customers. Please try again.",
  kAdminReviewsLoadFailed: "Couldn't load the review queue. Please try again.",
  kAdminReviewUpdateFailed: "Couldn't update the review. Please try again.",
};

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  group('failureCopyForCode', () {
    test('every code resolves to exact English copy', () {
      for (final entry in _expectedEn.entries) {
        expect(failureCopyForCode(en, entry.key), entry.value,
            reason: 'code ${entry.key}');
      }
    });

    test('no code falls back to English in Arabic', () {
      // The defect class this mapper closes: an Arabic shopper reading English.
      // Asserted as difference, so adding a code without Arabic copy fails here
      // even though the key would still be "non-empty".
      for (final code in _expectedEn.keys) {
        final arabic = failureCopyForCode(ar, code);
        expect(arabic, isNotNull, reason: 'code $code has no Arabic copy');
        expect(arabic, isNotEmpty, reason: 'code $code is empty in Arabic');
        expect(arabic, isNot(failureCopyForCode(en, code)),
            reason: 'code $code is still English in Arabic');
      }
    });

    test('an unrecognized code is not this mapper\'s business', () {
      // Feature-owned codes (checkout, payments) must fall through to the
      // caller, which knows its own copy.
      expect(failureCopyForCode(en, 'checkout_failed'), isNull);
      expect(failureCopyForCode(en, 'payment_declined'), isNull);
      expect(failureCopyForCode(en, null), isNull);
    });
  });

  group('failureText precedence', () {
    test('a known code beats the English message', () {
      expect(
        failureText(en,
            code: kFailureLoad,
            message: 'Failed to load products',
            fallback: 'fallback'),
        "Couldn't load. Please try again.",
      );
    });

    test('server-authored prose passes through verbatim (P1 ruling)', () {
      const serverSaid = 'duplicate key value violates unique constraint';
      expect(
        failureText(en, code: null, message: serverSaid, fallback: 'fallback'),
        serverSaid,
      );
    });

    test('a null or blank message falls back, never rendering empty', () {
      expect(failureText(en, code: null, message: null, fallback: 'fallback'),
          'fallback');
      expect(failureText(en, code: null, message: '   ', fallback: 'fallback'),
          'fallback');
    });
  });
}
