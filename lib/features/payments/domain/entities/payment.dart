import '../../../../core/entities/money.dart';

/// Supported payment methods for the Egyptian market.
enum PaymentMethod {
  paymobCard('Paymob Card', 'Credit/Debit Card via Paymob', 'paymob_card'),
  cashOnDelivery('Cash on Delivery', 'Pay on delivery', 'cod');

  const PaymentMethod(this.label, this.description, this.serverValue);
  final String label;
  final String description;

  /// Canonical method string stored in `orders.payment_method`.
  ///
  /// The server gates on these exact values: `paymob-initiate` and the
  /// 035 claim RPC require `'paymob_card'`; COD confirm RPCs match
  /// `'%cash%'`/`'%cod%'`; 037/039 allowlist `('cod','card')`.
  /// Always send [serverValue] — never a display string or literal.
  final String serverValue;
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
