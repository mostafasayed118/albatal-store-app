import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../domain/entities/payment.dart';

/// User-safe failure construction for [PaymobPaymentService].
///
/// Extracted verbatim from the service so that file stays under the size
/// budget; every message below is covered by the service's scrub/parity
/// tests through the public API. Raw provider/transport exceptions are
/// never surfaced — they are logged diagnostic-only and replaced here.
///
/// Machine-readable codes are preserved on every failure so the UI can
/// localize app-authored text (audit 2026-09-19, sweep part 32).

/// Maps `confirm_cod_payment` machine-readable codes to user-safe messages.
String codFailureMessage(String code) => switch (code) {
      'authentication_required' => 'Please sign in to confirm your order.',
      'payment_not_found' =>
        'No Cash on Delivery payment found for this order.',
      'not_owner' => 'You can only confirm your own orders.',
      'payment_not_pending' => 'This payment has already been processed.',
      'payment_not_cod' => 'This order is not a Cash on Delivery order.',
      'order_not_found' => 'Order not found.',
      'order_not_pending' =>
        'This order can no longer be confirmed. Please check your orders.',
      'already_confirmed' =>
        'This order was already confirmed. Please check your orders.',
      _ => 'Failed to confirm payment. Please try again.',
    };

/// Maps `set_pending_order_payment_method` codes to user-safe messages.
String setMethodFailureMessage(String code) => switch (code) {
      'authentication_required' => 'Please sign in to continue.',
      'invalid_method' => 'Unsupported payment method.',
      'not_owner' => 'You can only modify your own orders.',
      'order_not_found' => 'Order not found.',
      'order_not_pending' =>
        'This order can no longer be modified. Please check your orders.',
      _ => 'Failed to set payment method. Please try again.',
    };

/// Maps `instapay-submit-proof` server messages to user-safe messages.
String proofServerFailureMessage(String serverMessage) =>
    switch (serverMessage) {
      'Pending InstaPay payment not found' =>
        'No pending InstaPay payment found for this order.',
      'Proof too large' =>
        'The screenshot is too large. Please attach a smaller image.',
      'Unsupported proof format' => 'Unsupported screenshot format.',
      'Upload failed' => 'Could not upload the screenshot. Please try again.',
      _ => 'Could not submit the proof. Please try again.',
    };

/// Rejects an invalid proof before upload, or null when it may be sent.
///
/// [ext] must already be lowercased + trimmed — the same normalization
/// the service applies before putting it in the request body.
PaymentFailed? validateInstapayProof({
  required List<int> proofBytes,
  required String ext,
}) {
  const allowed = {'png', 'jpg', 'jpeg', 'webp'};
  if (proofBytes.isEmpty) {
    return const PaymentFailed(
      message: 'Attach the transfer screenshot to continue.',
      code: 'proof_missing',
    );
  }
  if (!allowed.contains(ext)) {
    return const PaymentFailed(
      message: 'Unsupported screenshot format.',
      code: 'unsupported_format',
    );
  }
  return null;
}

/// Non-200 `paymob-initiate` response: normalizes the untyped payload
/// through [safeMap] so a mistyped body degrades to [fallback].
PaymentFailed paymobInitiateFailure(Object? data, {required String fallback}) =>
    PaymentFailed(
      message: safeString(safeMap(data), 'message', fallback: fallback),
    );

/// RPC/edge timeout with a caller-supplied user-safe message.
PaymentFailed paymobTimeoutFailure(String message) =>
    PaymentFailed(message: message, code: 'rpc_timeout');

/// Non-200 `instapay-initiate` response: normalizes the untyped payload
/// through [safeMap] so a mistyped body degrades to [fallback].
InstapayUnavailable instapayInitiateFailure(Object? data,
        {required String fallback}) =>
    InstapayUnavailable(
      message: safeString(safeMap(data), 'message', fallback: fallback),
    );

/// `instapay-initiate` timeout with a caller-supplied user-safe message.
InstapayUnavailable instapayTimeoutFailure(String message) =>
    InstapayUnavailable(message: message, code: 'rpc_timeout');

/// `instapay-initiate` transport failure: logs the raw error
/// diagnostic-only, returns the scrubbed user-safe [message].
InstapayUnavailable instapayNetworkFailure({
  required Object error,
  required String logMessage,
  required String message,
}) {
  Log.e(logMessage, error: error, category: LogCategory.payment);
  return InstapayUnavailable(message: message, code: 'network_error');
}

/// Transport failure: logs the raw error diagnostic-only, returns the
/// scrubbed user-safe [message].
PaymentFailed paymobNetworkFailure({
  required Object error,
  required String logMessage,
  required String message,
  String code = 'network_error',
}) {
  Log.e(logMessage, error: error, category: LogCategory.payment);
  return PaymentFailed(message: message, code: code);
}
