import 'dart:async';

import '../../../../core/entities/money.dart';
import '../entities/payment.dart';

/// Abstraction for payment processing.
///
/// SECURITY NOTE: there is intentionally NO `verifyPayment`
/// method on this interface. Payment success is decided
/// server-side by the `/paymob-callback` webhook (after HMAC
/// verification) and observed by the client only through
/// [watchPaymentStatus]. Flutter must never parse a callback
/// URL to decide that a payment succeeded.
abstract interface class PaymentService {
  /// Initialize payment with the given amount and method.
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  });

  /// Watch a payment's status as it is updated server-side.
  ///
  /// Emits [PaymentSuccess] when the webhook marks the row as `success`,
  /// [PaymentFailed] when marked as `failed`. The data layer owns the
  /// underlying Realtime subscription and DB row parsing — the
  /// presentation layer only consumes the typed stream. The stream
  /// completes when the cubit cancels its subscription (e.g. on
  /// terminal status or [close]).
  Stream<PaymentResult> watchPaymentStatus(String orderId);
}
