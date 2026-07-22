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
///
/// COD is also server-confirmed: [confirmCodPayment] calls the
/// `confirm_cod_payment` RPC which atomically marks the payment
/// as success and the order as paid. The client never declares
/// COD success without a server response.
abstract interface class PaymentService {
  /// Initialize payment with the given amount and method.
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  });

  /// Confirm a Cash on Delivery payment server-side.
  ///
  /// Calls the `confirm_cod_payment` RPC which atomically transitions
  /// the order from `pending` to `paid` and records the COD payment
  /// as successful with a server-generated transaction ID.
  ///
  /// Returns [PaymentSuccess] on success, [PaymentFailed] on
  /// rejection (e.g. order already cancelled, expired, not pending).
  Future<PaymentResult> confirmCodPayment({required String orderId});

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
