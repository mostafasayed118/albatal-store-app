import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
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
        final data = response.data;
        return PaymentFailed(
          message: data['message'] ?? 'Payment initiation failed',
        );
      }

      final data = response.data;
      final checkoutUrl = data['checkout_url'] as String?;
      if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
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

      final data = response as Map<String, dynamic>;
      final ok = data['ok'] as bool? ?? false;
      final code = data['code'] as String? ?? 'unknown';

      // The server returns ok=true only for 'confirmed' and
      // 'already_confirmed'. Trust ok as the authoritative signal
      // and use the server-generated transaction_id.
      if (ok) {
        return PaymentSuccess(
          transactionId: data['transaction_id'] as String? ?? '',
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
      return PaymentFailed(
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

      final data = response as Map<String, dynamic>;
      final ok = data['ok'] as bool? ?? false;
      final code = data['code'] as String? ?? 'unknown';

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
      return PaymentFailed(
        message: 'Failed to set payment method. Please try again.',
        code: 'network_error',
      );
    }
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
              final newRecord = payload.newRecord;
              final status = newRecord['status'] as String?;
              if (status == 'success') {
                final transactionId =
                    newRecord['transaction_id'] as String? ?? '';
                if (!controller.isClosed && !hasEmitted) {
                  hasEmitted = true;
                  if (!completer.isCompleted) completer.complete();
                  fallbackTimer?.cancel();
                  controller.add(PaymentSuccess(
                    transactionId: transactionId,
                    amount: Money.zero,
                  ));
                }
              } else if (status == 'failed') {
                if (!controller.isClosed && !hasEmitted) {
                  hasEmitted = true;
                  if (!completer.isCompleted) completer.complete();
                  fallbackTimer?.cancel();
                  controller.add(const PaymentFailed(
                    message: 'Payment was declined by the gateway',
                  ));
                }
              }
              // Other status values (e.g. 'pending') are ignored — the
              // webhook will update the row again when terminal.
            },
          )
          .subscribe();

      fallbackTimer = Timer(const Duration(seconds: 45), () async {
        if (completer.isCompleted) return;
        if (controller.isClosed) return;
        if (hasEmitted) return;
        try {
          final row = await _client
              .from('payments')
              .select('status, transaction_id')
              .eq('order_id', orderId)
              .maybeSingle();
          if (completer.isCompleted) return;
          if (controller.isClosed) return;
          if (hasEmitted) return;
          if (row == null) return;
          final status = row['status'] as String?;
          if (status == 'success') {
            hasEmitted = true;
            if (!completer.isCompleted) completer.complete();
            controller.add(PaymentSuccess(
              transactionId: row['transaction_id'] as String? ?? '',
              amount: Money.zero,
            ));
          } else if (status == 'failed') {
            hasEmitted = true;
            if (!completer.isCompleted) completer.complete();
            controller.add(const PaymentFailed(
              message: 'Payment was declined by the gateway',
            ));
          }
        } catch (_) {
          // Fallback poll failure is silent — realtime may still deliver.
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
