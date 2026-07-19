import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/payment.dart';
import '../domain/repositories/payment_service.dart';

/// Paymob integration using server-side Edge Functions.
///
/// All sensitive operations (API key, auth token, order registration,
/// payment key generation) run through Edge Functions — never exposed
/// to the client.
class PaymobPaymentService implements PaymentService {
  PaymobPaymentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<PaymentResult> initiatePayment({
    required double amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    try {
      final amountCents = (amount * 100).round();

      // Step 1: Get auth token via Edge Function
      final authResponse = await _client.functions.invoke('paymob-auth');
      if (authResponse.status != 200) {
        return PaymentFailed(message: 'Failed to initialize payment');
      }
      final authToken = authResponse.data['token'] as String;

      // Step 2: Register order via Edge Function
      final orderResponse = await _client.functions.invoke(
        'paymob-order',
        body: {
          'auth_token': authToken,
          'amount_cents': amountCents,
          'items': [],
        },
      );
      if (orderResponse.status != 200) {
        return PaymentFailed(message: 'Failed to register order');
      }
      final paymobOrderId = orderResponse.data['order_id'].toString();

      // Step 3: Get payment key via Edge Function
      final keyResponse = await _client.functions.invoke(
        'paymob-payment-key',
        body: {
          'auth_token': authToken,
          'order_id': paymobOrderId,
          'amount_cents': amountCents,
          'email': customerEmail,
        },
      );
      if (keyResponse.status != 200) {
        return PaymentFailed(message: 'Failed to get payment key');
      }
      final paymentKey = keyResponse.data['payment_key'] as String;

      return PaymentPending(paymentKey: paymentKey);
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
        return PaymentSuccess(transactionId: transactionId, amount: 0);
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

  @override
  Future<PaymentResult> processVodafoneCash({
    required double amount,
    required String phoneNumber,
    required String orderId,
  }) async {
    return PaymentFailed(
        message: 'Use VodafoneCashPaymentService for mobile wallet payments');
  }

  /// Paymob checkout URL for web view.
  String getCheckoutUrl(String paymentKey) =>
      'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=$paymentKey';
}
