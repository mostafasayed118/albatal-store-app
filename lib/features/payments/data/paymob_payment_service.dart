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
      final checkoutUrl = data['checkout_url'] as String;
      final paymentKey = data['payment_key'] as String;

      return PaymentPending(paymentKey: paymentKey, checkoutUrl: checkoutUrl);
    } catch (e) {
      return PaymentFailed(message: 'Payment initialization failed: $e');
    }
  }

  @override
  Future<PaymentResult> verifyPayment(String callbackData) async {
    try {
      final data = Uri.splitQueryString(callbackData);
      final success = data['success'] == 'true';
      final transactionId = data['id'] ?? '';

      if (success) {
        return PaymentSuccess(
          transactionId: transactionId,
          amount: Money.zero,
        );
      } else {
        return PaymentFailed(
          message: data['message'] ?? 'Payment failed',
          code: data['code'],
        );
      }
    } catch (e) {
      return PaymentFailed(message: 'Payment verification failed: $e');
    }
  }
}
