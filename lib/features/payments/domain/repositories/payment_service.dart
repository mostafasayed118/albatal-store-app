import '../entities/payment.dart';

/// Abstraction for payment processing.
abstract interface class PaymentService {
  /// Initialize payment with the given amount and method.
  Future<PaymentResult> initiatePayment({
    required double amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  });

  /// Verify a payment callback from the payment gateway.
  Future<PaymentResult> verifyPayment(String callbackData);

  /// Process Vodafone Cash payment with phone number.
  Future<PaymentResult> processVodafoneCash({
    required double amount,
    required String phoneNumber,
    required String orderId,
  });
}
