import '../../../../core/entities/money.dart';

/// Supported payment methods for the Egyptian market.
enum PaymentMethod {
  paymobCard('Paymob Card', 'Credit/Debit Card via Paymob'),
  // TODO(phase-2): implement real Vodafone Cash integration.
  // Stubs removed in chore/remove-vodafone-cash-stubs — re-add service + page
  // + edge functions when integrating the Vodafone Cash API.
  vodafoneCash('Vodafone Cash', 'Mobile Wallet'),
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
  const PaymentPending({required this.paymentKey});
  final String paymentKey;
}

class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}
