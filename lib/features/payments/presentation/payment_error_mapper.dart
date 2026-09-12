import '../../../generated/l10n/app_localizations.dart';

String paymentMessageForCode(
    AppLocalizations l10n, String? code, String fallback) {
  return switch (code) {
    'payment_not_pending' => l10n.paymentNotPending,
    'payment_not_cod' => l10n.paymentNotPending,
    'order_ref_required' => l10n.orderRefRequired,
    'verify_failed' => l10n.paymentVerifyFailed,
    'verify_timeout' => l10n.paymentTimeout,
    'rpc_timeout' => l10n.paymentTimeout,
    'network_error' => l10n.paymentGenericFailure,
    // Paymob/COD allowlist codes (server-authoritative): map to the
    // closest localized copy so Arabic users never see raw English.
    'authentication_required' => l10n.orderRefRequired,
    'payment_not_found' => l10n.paymentNotPending,
    'not_owner' => l10n.paymentGenericFailure,
    'order_not_found' => l10n.orderRefRequired,
    'order_not_pending' => l10n.paymentNotPending,
    'already_confirmed' => l10n.paymentNotPending,
    'invalid_method' => l10n.paymentGenericFailure,
    'proof_missing' => l10n.paymentGenericFailure,
    'unsupported_format' => l10n.paymentGenericFailure,
    'expired' => l10n.paymentExpiredRetry,
    _ => fallback,
  };
}
