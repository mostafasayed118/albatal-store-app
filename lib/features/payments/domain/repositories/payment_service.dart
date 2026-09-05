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

  /// Record the customer's chosen payment method on a pending order.
  ///
  /// Calls the `set_pending_order_payment_method` RPC. The checkout
  /// flow creates the order before the customer picks a method on the
  /// payment screen, so the method must be updated server-side before
  /// [confirmCodPayment] (which requires a COD-like stored method).
  /// Only the order owner may change the method, only while the order
  /// is `pending`, and only to an allowlisted value
  /// (`cod`, `card`, `instapay` — migration 041).
  ///
  /// Returns [PaymentSuccess] (empty transaction ID) on success,
  /// [PaymentFailed] with a machine-readable code otherwise.
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  });

  /// Prepare an InstaPay transfer for a pending order (migration 041).
  ///
  /// Switches the order's method server-side via the 041 allowlist RPC
  /// (owner-checked; ensures the single pending 'instapay' payments
  /// row) and returns the merchant InstaPay address + the
  /// server-authoritative amount as [InstapayReady]. The address comes
  /// from the server env and the amount from the DB — neither is ever
  /// client-supplied.
  ///
  /// Returns [InstapayUnavailable] with a machine-readable code when
  /// the order is not pending/owned, or when InstaPay is not
  /// configured server-side (the function fails closed).
  Future<InstapayInitiation> initiateInstapayPayment({required String orderId});

  /// Submit a transfer proof for the pending InstaPay payment of an
  /// order the caller owns (migration 041).
  ///
  /// [proofBytes] is the encoded image picked on the device;
  /// [fileExt] must be one of the server-validated extensions
  /// (`png`, `jpg`, `jpeg`, `webp`). [reference] is an optional
  /// transfer reference number.
  ///
  /// The proof lands in the private `instapay-proofs` bucket and the
  /// payment STAYS `pending` — success is decided only by admin review
  /// or the 24h expiry. Returns [PaymentSuccess] (empty transaction
  /// ID) when the proof is recorded.
  Future<PaymentResult> submitInstapayProof({
    required String orderId,
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
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
