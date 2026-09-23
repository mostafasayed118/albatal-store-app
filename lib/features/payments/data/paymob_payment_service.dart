import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
import '../../../core/utils/safe_parse.dart';
import '../domain/entities/payment.dart';
import '../domain/repositories/payment_service.dart';
import 'payment_status_watcher.dart';
import 'paymob_failures.dart';

/// Paymob integration using a single server-side Edge Function.
///
/// All sensitive operations (API key, auth token, order registration,
/// payment key generation) run through [paymob-initiate] — never
/// exposed to the client. The checkout URL is returned so the client
/// can open it in a WebView.
///
/// Also owns the Supabase Realtime subscription that watches the
/// `payments` table for server-side status updates (written by the
/// `/paymob-callback` webhook). DB row parsing lives here, not in
/// the presentation layer.
class PaymobPaymentService implements PaymentService {
  PaymobPaymentService({required SupabaseClient client})
      : _client = client,
        _watcher = PaymentStatusWatcher(client: client);

  final SupabaseClient _client;
  final PaymentStatusWatcher _watcher;

  /// Initiates a Paymob payment via a single Edge Function call.
  ///
  /// [amount] must match the server-computed total_cents — the Edge
  /// Function rejects mismatches. [orderId] is the internal order ID
  /// returned by the `/checkout` Edge Function.
  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'paymob-initiate',
        body: {
          'order_id': orderId,
          'amount_cents': amount.minorUnits,
          'customer_email': customerEmail,
        },
      );

      if (response.status != 200) {
        return paymobInitiateFailure(response.data,
            fallback: 'Payment initiation failed');
      }

      final checkoutUrl = safeString(safeMap(response.data), 'checkout_url');
      if (checkoutUrl.trim().isEmpty) {
        return const PaymentFailed(
          message: 'Payment provider returned an invalid checkout session.',
          // App-authored text must carry a code so the UI can localize it
          // (audit 2026-09-19, sweep part 32). 'payment_session_invalid' maps to
          // the generic payment copy in payment_error_mapper.dart.
          code: 'payment_session_invalid',
        );
      }

      return PaymentPending(checkoutUrl: checkoutUrl);
    } catch (e) {
      // Scrubbed: never surface raw provider/transport exceptions to the
      // UI (they can leak URLs, tokens, or internal details).
      // Structured log keeps the detail diagnostic-only (never in the UI).
      return paymobNetworkFailure(
        error: e,
        logMessage: 'Paymob initiate failed',
        message: 'Payment could not be started. Please try again.',
        code: 'payment_start_failed',
      );
    }
  }

  /// Confirm a Cash on Delivery payment via the `confirm_cod_payment` RPC.
  ///
  /// The RPC:
  ///   - Verifies authentication
  ///   - Locates the COD payment for this order + user
  ///   - Checks the order is still `pending`
  ///   - Atomically sets payment.status='success' and order.status='paid'
  ///   - Returns a server-generated transaction ID
  ///
  /// Returns [PaymentSuccess] with the server transaction ID on success,
  /// [PaymentFailed] with a machine-readable code on rejection.
  /// Timeout for the confirm_cod_payment RPC call.
  ///
  /// The RPC is a single atomic DB transaction; under normal load it
  /// completes in <2 s. A 30 s ceiling covers cold starts and replica
  /// lag while keeping the user from waiting indefinitely.
  static const _rpcTimeout = Duration(seconds: 30);

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    try {
      final response = await _client.rpc(
        'confirm_cod_payment',
        params: {
          'p_order_id': orderId,
        },
      ).timeout(_rpcTimeout);

      // The RPC returns a JSON object, but the decoded shape is untyped:
      // normalize through [safeMap] so a mistyped payload degrades to
      // `ok: false` + the generic message instead of throwing.
      final data = safeMap(response);
      final ok = safeBool(data, 'ok');
      final code = safeString(data, 'code', fallback: 'unknown');

      // The server returns ok=true only for 'confirmed' and
      // 'already_confirmed'. Trust ok as the authoritative signal
      // and use the server-generated transaction_id.
      if (ok) {
        return PaymentSuccess(
          transactionId: safeString(data, 'transaction_id'),
          amount: Money.zero,
        );
      }

      // Map machine-readable codes to user-safe messages.
      return PaymentFailed(message: codFailureMessage(code), code: code);
    } on TimeoutException {
      return paymobTimeoutFailure(
        'Server did not respond in time. Please check your orders and try again.',
      );
    } catch (e) {
      return paymobNetworkFailure(
        error: e,
        logMessage: 'COD confirm failed',
        message: 'Failed to confirm payment. Please try again.',
      );
    }
  }

  /// Record the customer's chosen payment method on a pending order.
  ///
  /// Calls the `set_pending_order_payment_method` RPC (see migration
  /// 037). Same 30 s ceiling as [confirmCodPayment].
  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async {
    try {
      final response = await _client.rpc(
        'set_pending_order_payment_method',
        params: {
          'p_order_id': orderId,
          'p_method': method,
        },
      ).timeout(_rpcTimeout);

      final data = safeMap(response);
      final ok = safeBool(data, 'ok');
      final code = safeString(data, 'code', fallback: 'unknown');

      if (ok) {
        return const PaymentSuccess(transactionId: '', amount: Money.zero);
      }

      return PaymentFailed(
          message: setMethodFailureMessage(code), code: code);
    } on TimeoutException {
      return paymobTimeoutFailure(
        'Server did not respond in time. Please check your orders and try again.',
      );
    } catch (e) {
      return paymobNetworkFailure(
        error: e,
        logMessage: 'Set order payment method failed',
        message: 'Failed to set payment method. Please try again.',
      );
    }
  }

  /// Prepare an InstaPay transfer via the `instapay-initiate` Edge
  /// Function (migration 041).
  ///
  /// The function switches the order's method through the 041
  /// owner-checked allowlist RPC, then returns the env-configured
  /// merchant InstaPay address and the server-authoritative amount.
  /// The client never supplies either.
  @override
  Future<InstapayInitiation> initiateInstapayPayment(
      {required String orderId}) async {
    try {
      final response = await _client.functions.invoke(
        'instapay-initiate',
        body: {'order_id': orderId},
      ).timeout(_rpcTimeout);

      if (response.status != 200) {
        return instapayInitiateFailure(response.data,
            fallback: 'InstaPay is unavailable right now.');
      }

      final data = safeMap(response.data);
      final paymentId = safeString(data, 'payment_id');
      final address = safeString(data, 'instapay_address');
      final amountCents = safeInt(data, 'amount');

      if (paymentId.isEmpty || address.isEmpty || amountCents <= 0) {
        return const InstapayUnavailable(
          message: 'InstaPay returned an invalid transfer session.',
          code: 'instapay_session_invalid',
        );
      }

      return InstapayReady(
        instructions: InstapayInstructions(
          paymentId: paymentId,
          instapayAddress: address,
          amount: Money(amountCents),
        ),
      );
    } on TimeoutException {
      return instapayTimeoutFailure(
        'Server did not respond in time. Please check your orders and try again.',
      );
    } catch (e) {
      return instapayNetworkFailure(
        error: e,
        logMessage: 'InstaPay initiate failed',
        message: 'InstaPay could not be started. Please try again.',
      );
    }
  }

  /// Submit a transfer proof via the `instapay-submit-proof` Edge
  /// Function (migration 041).
  ///
  /// The pending payment is located server-side by (order, user);
  /// the proof lands in the private `instapay-proofs` bucket and the
  /// payment stays `pending` — success is decided only by admin
  /// review (or the 24h expiry), never by this call.
  @override
  Future<PaymentResult> submitInstapayProof({
    required String orderId,
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
  }) async {
    try {
      final ext = fileExt.toLowerCase().trim();
      final invalid = validateInstapayProof(
        proofBytes: proofBytes,
        ext: ext,
      );
      if (invalid != null) return invalid;

      final response = await _client.functions.invoke(
        'instapay-submit-proof',
        body: {
          'order_id': orderId,
          'proof_base64': base64Encode(proofBytes),
          'file_ext': ext,
          if (reference != null && reference.trim().isNotEmpty)
            'reference': reference.trim(),
        },
      ).timeout(_rpcTimeout);

      if (response.status == 201) {
        return const PaymentSuccess(transactionId: '', amount: Money.zero);
      }

      final message = proofServerFailureMessage(
        safeString(safeMap(response.data), 'message'),
      );
      return PaymentFailed(message: message);
    } on TimeoutException {
      return paymobTimeoutFailure(
        'Server did not respond in time. Please try again.',
      );
    } catch (e) {
      return paymobNetworkFailure(
        error: e,
        logMessage: 'InstaPay proof submission failed',
        message: 'Could not submit the proof. Please try again.',
      );
    }
  }

  /// Subscribe to the `payments` row for [orderId] via Supabase Realtime.
  ///
  /// Delegates to [PaymentStatusWatcher.watch]; single-subscription
  /// semantics are owned by the watcher.
  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      _watcher.watch(orderId);
}
