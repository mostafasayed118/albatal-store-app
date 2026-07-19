import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/payment.dart';
import '../domain/repositories/payment_service.dart';

/// Vodafone Cash mobile wallet payment service.
/// Verification is idempotent — duplicate calls return the same result.
class VodafoneCashPaymentService implements PaymentService {
  VodafoneCashPaymentService({
    required this.merchantCode,
    required this.apiKey,
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final String merchantCode;
  final String apiKey;
  final SupabaseClient _client;

  @override
  Future<PaymentResult> processVodafoneCash({
    required double amount,
    required String phoneNumber,
    required String orderId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'vodafone-cash-payment',
        body: {
          'amount': (amount * 100).round(),
          'phone_number': phoneNumber,
          'order_id': orderId,
          'merchant_code': merchantCode,
        },
      );

      if (response.status != 200) {
        final error = response.data;
        return PaymentFailed(
            message: error['message'] ?? 'Vodafone Cash payment failed');
      }

      final data = response.data;
      final transactionId = data['transaction_id'] as String?;

      if (transactionId != null) {
        return PaymentPending(paymentKey: transactionId);
      }

      return PaymentFailed(message: 'No transaction ID received');
    } catch (e) {
      return PaymentFailed(message: 'Vodafone Cash error: $e');
    }
  }

  /// Verify Vodafone Cash payment status.
  /// Idempotent: calling multiple times returns the same result.
  Future<PaymentResult> verifyVodafoneCashPayment(String transactionId) async {
    try {
      final response = await _client.functions.invoke(
        'vodafone-cash-verify',
        body: {'transaction_id': transactionId},
      );

      if (response.status != 200) {
        return PaymentFailed(message: 'Verification failed');
      }

      final data = response.data;
      final status = data['status'] as String?;

      if (status == 'SUCCESS') {
        return PaymentSuccess(
          transactionId: transactionId,
          amount: (data['amount'] as int? ?? 0) / 100,
        );
      } else if (status == 'PENDING') {
        return PaymentPending(paymentKey: transactionId);
      } else {
        return PaymentFailed(message: data['message'] ?? 'Payment failed');
      }
    } catch (e) {
      return PaymentFailed(message: 'Verification error: $e');
    }
  }

  @override
  Future<PaymentResult> initiatePayment({
    required double amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    return PaymentFailed(
        message: 'Use processVodafoneCash() for mobile wallet payments');
  }

  @override
  Future<PaymentResult> verifyPayment(String callbackData) async {
    return verifyVodafoneCashPayment(callbackData);
  }
}
