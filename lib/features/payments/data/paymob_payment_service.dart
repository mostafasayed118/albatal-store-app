import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../domain/entities/payment.dart';
import '../domain/repositories/payment_service.dart';

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
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
        return PaymentSuccess(transactionId: '', amount: Money.zero);
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

  /// Maps a `payments` row to its terminal [PaymentResult].
  ///
  /// Single shared mapping for BOTH the realtime callback and the 45s
  /// fallback poll in [watchPaymentStatus] — identical rows always yield
  /// identical payloads. Returns null for non-terminal rows
  /// (`pending`/unknown/missing status) so both callers keep polling.
  /// Payloads are byte-identical to the pre-refactor inline branches
  /// (no `code` on the gateway-decline failure — codes unchanged).
  @visibleForTesting
  static PaymentResult? terminalResultForRow(Map<String, dynamic> row) {
    final status = safeString(row, 'status');
    if (status == 'success') {
      return PaymentSuccess(
        transactionId: safeString(row, 'transaction_id'),
        amount: Money.zero,
      );
    }
    if (status == 'failed') {
      return const PaymentFailed(
        message: 'Payment was declined by the gateway',
      );
    }
    return null;
  }

  /// Subscribe to the `payments` row for [orderId] via Supabase Realtime.
  ///
  /// The `/paymob-callback` webhook updates the row server-side; this
  /// stream observes those updates and emits a terminal [PaymentResult]
  /// when `status` becomes `success` or `failed`. The returned stream
  /// is single-subscription — the cubit owns its subscription and
  /// cancels it on terminal status or [close]. Cancelling the
  /// subscription also unsubscribes the Realtime channel so we don't
  /// leak DB listeners.
  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) {
    final controller = StreamController<PaymentResult>();
    RealtimeChannel? channel;
    Timer? fallbackTimer;
    final completer = Completer<void>();
    bool hasEmitted = false;

    // Single shared terminal-emission path for the realtime callback
    // and the fallback poll below: exactly-once add, cancels the
    // fallback timer, completes the `done` completer.
    void emitTerminal(PaymentResult result) {
      if (completer.isCompleted || controller.isClosed || hasEmitted) return;
      hasEmitted = true;
      if (!completer.isCompleted) completer.complete();
      fallbackTimer?.cancel();
      controller.add(result);
    }

    controller.onListen = () {
      channel = _client
          .channel('payment-$orderId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'order_id',
              value: orderId,
            ),
            callback: (payload) {
              if (completer.isCompleted) return;
              final result =
                  PaymobPaymentService.terminalResultForRow(payload.newRecord);
              if (result != null) emitTerminal(result);
              // Other status values (e.g. 'pending') are ignored — the
              // webhook will update the row again when terminal.
            },
          )
          .subscribe();

      // Periodic fallback poll (was one-shot). Supabase Realtime
      // postgres_changes delivery was observed silently broken on
      // staging (subscriptions accepted, realtime.subscription never
      // populated, zero events — see
      // docs/evidence/ffaa420/STAGING_E2E_INSTAPAY.md). A single
      // 45s poll cannot cover InstaPay, where admin approval happens
      // at an arbitrary later time, so keep polling until a terminal
      // status is observed. The 15-minute watch timeout in
      // PaymentCubit still bounds the total wait; cancelling the
      // subscription (onListen/onCancel) cancels this timer. The
      // in-flight guard prevents overlapping polls if a poll is
      // slower than the interval.
      var pollInFlight = false;
      fallbackTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
        if (pollInFlight ||
            completer.isCompleted ||
            controller.isClosed ||
            hasEmitted) {
          return;
        }
        pollInFlight = true;
        try {
          final row = await _client
              .from('payments')
              .select('status, transaction_id')
              .eq('order_id', orderId)
              .maybeSingle();
          if (completer.isCompleted || controller.isClosed || hasEmitted) {
            return;
          }
          if (row == null) return; // keep polling — nothing yet
          final result = PaymobPaymentService.terminalResultForRow(row);
          if (result != null) emitTerminal(result);
          // Other statuses (e.g. 'pending') keep the poll running.
        } catch (_) {
          // Fallback poll failure is silent — realtime may still deliver.
        } finally {
          pollInFlight = false;
        }
      });
    };

    controller.onCancel = () {
      fallbackTimer?.cancel();
      channel?.unsubscribe();
    };

    return controller.stream;
  }
}
