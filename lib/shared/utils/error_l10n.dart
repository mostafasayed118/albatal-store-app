import 'package:flutter/widgets.dart';

import '../../generated/l10n/app_localizations.dart';

/// Localized error messages from machine-readable error codes
/// (audit 2026-09-14).
///
/// Cubits emit [AppError.message] (an English fallback string) plus —
/// when the data layer assigned one — `AppError.code`. This helper maps
/// the code to a localized ARB message; unknown codes or a missing
/// [AppLocalizations] fall back to the original message, preserving the
/// English behavior for unmapped cases (same fallback contract as
/// `paymentMessageForCode`).
///
/// The codes the data layer and payment cubit actually emit:
///  * `checkout_failed` / `coupon_invalid` / `coupon_unavailable`
///  * `review_invalid` / `review_unavailable` / `review_buy_required`
///  * `oauth_cancelled` / `oauth_unavailable`
///  * `orders_load_failed`
///  * payment codes: `network_error`, `verify_failed`, `verify_timeout`,
///    `rpc_timeout`, `payment_not_pending`, `payment_not_cod`,
///    `order_ref_required`
///  * auth/delete codes from `_mapAuthError` / `_mapDeleteError`
///    (`auth_*`, `delete_*`)
const Set<String> knownErrorCodes = {
  'checkout_failed',
  'coupon_invalid',
  'coupon_unavailable',
  'review_invalid',
  'review_unavailable',
  'review_buy_required',
  'oauth_cancelled',
  'oauth_unavailable',
  'orders_load_failed',
  'network_error',
  'verify_failed',
  'verify_timeout',
  'rpc_timeout',
  'payment_not_pending',
  'payment_not_cod',
  'order_ref_required',
  'auth_invalid_credentials',
  'auth_email_not_confirmed',
  'auth_email_taken',
  'auth_weak_password',
  'auth_unexpected',
  'auth_signup_failed',
  'auth_signin_failed',
  'auth_session_expired',
  'delete_email_mismatch',
  'delete_admin_account',
  'delete_other_account',
  'delete_failed',
};

/// Code → localized copy. [fallback] is returned for null or unknown
/// codes so server-authored messages pass through verbatim (P1 ruling).
/// Pure (no [BuildContext]) so it is unit-testable like
/// `paymentMessageForCode`.
String localizedErrorText(AppLocalizations l10n, String? code, String fallback) {
  return switch (code) {
    'checkout_failed' => l10n.checkoutFailedRetry,
    'coupon_invalid' => l10n.couponInvalid,
    'coupon_unavailable' => l10n.errorCodesCouponUnavailable,
    'review_invalid' => l10n.errorCodesReviewInvalid,
    'review_unavailable' => l10n.errorCodesReviewUnavailable,
    'review_buy_required' => l10n.errorCodesReviewBuyRequired,
    'oauth_cancelled' => l10n.oauthCancelled,
    'oauth_unavailable' => l10n.oauthUnavailable,
    'orders_load_failed' => l10n.errorCodesOrdersLoadFailed,
    // Payment codes (payment_cubit emits these as raw errorMessage values,
    // the Paymob service sets them as AppError.code) — reuse the existing
    // payment ARB keys.
    'network_error' => l10n.paymentGenericFailure,
    'verify_failed' => l10n.paymentVerifyFailed,
    'verify_timeout' || 'rpc_timeout' => l10n.paymentTimeout,
    'payment_not_pending' || 'payment_not_cod' => l10n.paymentNotPending,
    'order_ref_required' => l10n.orderRefRequired,
    // Auth failure classes from _mapAuthError / _mapDeleteError.
    'auth_invalid_credentials' => l10n.errorCodesAuthInvalidCredentials,
    'auth_email_not_confirmed' => l10n.errorCodesAuthEmailNotConfirmed,
    'auth_email_taken' => l10n.errorCodesAuthEmailTaken,
    'auth_weak_password' => l10n.errorCodesAuthWeakPassword,
    'auth_unexpected' => l10n.errorCodesAuthUnexpected,
    'auth_signup_failed' => l10n.errorCodesAuthSignupFailed,
    'auth_signin_failed' => l10n.errorCodesAuthSigninFailed,
    'auth_session_expired' => l10n.errorCodesAuthSessionExpired,
    'delete_email_mismatch' => l10n.errorCodesDeleteEmailMismatch,
    'delete_admin_account' => l10n.errorCodesDeleteAdminAccount,
    'delete_other_account' => l10n.errorCodesDeleteOtherAccount,
    'delete_failed' => l10n.errorCodesDeleteFailed,
    _ => fallback,
  };
}

/// Context wrapper over [localizedErrorText]: resolves
/// [AppLocalizations] when one is mounted (null-safe so widget tests
/// without delegates keep the raw fallback), and also treats a bare
/// code-as-message the way payment_cubit emits them (`errorMessage`
/// carrying `network_error` etc.) and kOAuthCancelled in the OAuth
/// service. Null [message] passes through as null so call sites can
/// keep their `?? localized-default` shapes.
String? localizedErrorMessage(
  BuildContext context,
  String? message, {
  String? code,
}) {
  if (message == null) return null;
  final effectiveCode =
      code ?? (knownErrorCodes.contains(message) ? message : null);
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return message;
  return localizedErrorText(l10n, effectiveCode, message);
}
