import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../domain/entities/payment.dart';
import '../domain/repositories/payment_service.dart';
import 'payment_status_watcher.dart';

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
  PaymobPaymentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        _watcher =
            PaymentStatusWatcher(client: client ?? Supabase.instance.client);

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
        // `response.data` is untyped (Map, List, or String depending on
        // the transport): normalize through [safeMap] so a mistyped
        // payload degrades to the fallback message instead of throwing.
        final message = safeString(
          safeMap(response.data),
          'message',
          fallback: 'Payment initiation failed',
        );
        return PaymentFailed(message: message);
      }

      final checkoutUrl = safeString(safeMap(response.data), 'checkout_url');
      if (checkoutUrl.trim().isEmpty) {
        return const PaymentFailed(
          message: 'Payment provider returned an invalid checkout session.',
        );
      }

      return PaymentPending(checkoutUrl: checkoutUrl);
    } catch (e) {
      // Scrubbed: never surface raw provider/transport exceptions to the
      // UI (they can leak URLs, tokens, or internal details).
      // Structured log keeps the detail diagnostic-only (never in the UI).
      Log.e('Paymob initiate failed', error: e, category: LogCategory.payment);
      return const PaymentFailed(
        message: 'Payment could not be started. Please try again.',
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
      final message = switch (code) {
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

      return PaymentFailed(message: message, code: code);
    } on TimeoutException {
      return const PaymentFailed(
        message:
            'Server did not respond in time. Please check your orders and try again.',
        code: 'rpc_timeout',
      );
    } catch (e) {
      Log.e('COD confirm failed', error: e, category: LogCategory.payment);
      return const PaymentFailed(
        message: 'Failed to confirm payment. Please try again.',
        code: 'network_error',
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

      final message = switch (code) {
        'authentication_required' => 'Please sign in to continue.',
        'invalid_method' => 'Unsupported payment method.',
        'not_owner' => 'You can only modify your own orders.',
        'order_not_found' => 'Order not found.',
        'order_not_pending' =>
          'This order can no longer be modified. Please check your orders.',
        _ => 'Failed to set payment method. Please try again.',
      };

      return PaymentFailed(message: message, code: code);
    } on TimeoutException {
      return const PaymentFailed(
        message:
            'Server did not respond in time. Please check your orders and try again.',
        code: 'rpc_timeout',
      );
    } catch (e) {
      Log.e('Set order payment method failed',
          error: e, category: LogCategory.payment);
      return const PaymentFailed(
        message: 'Failed to set payment method. Please try again.',
        code: 'network_error',
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
        final message = safeString(
          safeMap(response.data),
          'message',
          fallback: 'InstaPay is unavailable right now.',
        );
        return InstapayUnavailable(message: message);
      }

      final data = safeMap(response.data);
      final paymentId = safeString(data, 'payment_id');
      final address = safeString(data, 'instapay_address');
      final amountCents = safeInt(data, 'amount');

      if (paymentId.isEmpty || address.isEmpty || amountCents <= 0) {
        return const InstapayUnavailable(
          message: 'InstaPay returned an invalid transfer session.',
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
      return const InstapayUnavailable(
        message:
            'Server did not respond in time. Please check your orders and try again.',
        code: 'rpc_timeout',
      );
    } catch (e) {
      Log.e('InstaPay initiate failed',
          error: e, category: LogCategory.payment);
      return const InstapayUnavailable(
        message: 'InstaPay could not be started. Please try again.',
        code: 'network_error',
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

      final message = switch (safeString(safeMap(response.data), 'message')) {
        'Pending InstaPay payment not found' =>
          'No pending InstaPay payment found for this order.',
        'Proof too large' =>
          'The screenshot is too large. Please attach a smaller image.',
        'Unsupported proof format' => 'Unsupported screenshot format.',
        'Upload failed' => 'Could not upload the screenshot. Please try again.',
        _ => 'Could not submit the proof. Please try again.',
      };
      return PaymentFailed(message: message);
    } on TimeoutException {
      return const PaymentFailed(
        message: 'Server did not respond in time. Please try again.',
        code: 'rpc_timeout',
      );
    } catch (e) {
      Log.e('InstaPay proof submission failed',
          error: e, category: LogCategory.payment);
      return const PaymentFailed(
        message: 'Could not submit the proof. Please try again.',
        code: 'network_error',
      );
    }
  }

  /// Compat forwarder — the realtime mapping now lives on
  /// [PaymentStatusWatcher]; kept so existing tests referencing
  /// `PaymobPaymentService.terminalResultForRow` compile unchanged.
  @visibleForTesting
  static PaymentResult? terminalResultForRow(Map<String, dynamic> row) =>
      PaymentStatusWatcher.terminalResultForRow(row);

  /// Subscribe to the `payments` row for [orderId] via Supabase Realtime.
  ///
  /// Delegates to [PaymentStatusWatcher.watch]; single-subscription
  /// semantics are owned by the watcher.
  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      _watcher.watch(orderId);
}
