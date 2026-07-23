import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
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
      return PaymentFailed(message: 'Payment initialization failed: $e');
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
  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    try {
      final response = await _client.rpc(
        'confirm_cod_payment',
        params: {
          'p_order_id': orderId,
        },
      );

      final data = response as Map<String, dynamic>;
      final ok = data['ok'] as bool? ?? false;
      final code = data['code'] as String? ?? 'unknown';

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
        'order_not_found' => 'Order not found.',
        'order_not_pending' =>
          'This order can no longer be confirmed. Please check your orders.',
        'already_confirmed' =>
          'This order was already confirmed. Please check your orders.',
        _ => 'Failed to confirm payment. Please try again.',
      };

      return PaymentFailed(message: message, code: code);
    } catch (e) {
      return PaymentFailed(
        message: 'Failed to confirm payment. Please try again.',
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
              final newRecord = payload.newRecord;
              final status = newRecord['status'] as String?;
              if (status == 'success') {
                final transactionId =
                    newRecord['transaction_id'] as String? ?? '';
                controller.add(PaymentSuccess(
                  transactionId: transactionId,
                  amount: Money.zero,
                ));
              } else if (status == 'failed') {
                controller.add(const PaymentFailed(
                  message: 'Payment was declined by the gateway',
                ));
              }
              // Other status values (e.g. 'pending') are ignored — the
              // webhook will update the row again when terminal.
            },
          )
          .subscribe();
    };

    controller.onCancel = () {
      channel?.unsubscribe();
    };

    return controller.stream;
  }
}
