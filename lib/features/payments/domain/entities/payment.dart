import '../../../../core/entities/money.dart';

/// Supported payment methods for the Egyptian market.
enum PaymentMethod {
  paymobCard('Paymob Card', 'Credit/Debit Card via Paymob'),
  cashOnDelivery('Cash on Delivery', 'Pay on delivery');

  const PaymentMethod(this.label, this.description);
  final String label;
  final String description;
}

/// Result of a payment operation.
sealed class PaymentResult {
  const PaymentResult();
}

class PaymentSuccess extends PaymentResult {
  const PaymentSuccess({required this.transactionId, required this.amount});
  final String transactionId;
  final Money amount;
}

class PaymentFailed extends PaymentResult {
  const PaymentFailed({required this.message, this.code});
  final String message;
  final String? code;
}

class PaymentPending extends PaymentResult {
  const PaymentPending({required this.checkoutUrl});
  final String checkoutUrl;
}

class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}
