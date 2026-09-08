import 'package:al_batal_elite/generated/l10n/app_localizations.dart';

String paymentMessageForCode(AppLocalizations l10n, String? code, String fallback) {
  return switch (code) {
    'payment_not_pending' => l10n.paymentNotPending,
    'payment_not_cod' => l10n.paymentNotPending,
    'order_ref_required' => l10n.orderRefRequired,
    'verify_failed' => l10n.paymentVerifyFailed,
    'verify_timeout' => l10n.paymentTimeout,
    'rpc_timeout' => l10n.paymentTimeout,
    'network_error' => l10n.paymentGenericFailure,
    _ => fallback,
  };
}
