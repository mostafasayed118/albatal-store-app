import '../../../../core/entities/money.dart';

/// Supported payment methods for the Egyptian market.
enum PaymentMethod {
  paymobCard('Paymob Card', 'Credit/Debit Card via Paymob', 'paymob_card'),
  cashOnDelivery('Cash on Delivery', 'Pay on delivery', 'cod'),
  instapay(
    'InstaPay',
    'Transfer via InstaPay, then submit the proof for review',
    'instapay',
  );

  const PaymentMethod(this.label, this.description, this.serverValue);
  final String label;
  final String description;

  /// Canonical method string stored in `orders.payment_method`.
  ///
  /// The server gates on these exact values: `paymob-initiate` and the
  /// 035 claim RPC require `'paymob_card'`; COD confirm RPCs match
  /// `'%cash%'`/`'%cod%'`; the 041 allowlist is `('cod','card','instapay')`.
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

/// Server-derived details for an InstaPay transfer (migration 041).
///
/// Both fields come from the server: the merchant address from the
/// edge-function env (`INSTAPAY_MERCHANT_ADDRESS`, never the client)
/// and the amount from the pending `payments` row — the client never
/// computes or supplies either.
class InstapayInstructions {
  const InstapayInstructions({
    required this.paymentId,
    required this.instapayAddress,
    required this.amount,
  });

  final String paymentId;
  final String instapayAddress;
  final Money amount;
}

/// Result of preparing an InstaPay transfer (migration 041).
sealed class InstapayInitiation {
  const InstapayInitiation();
}

/// The order is pending InstaPay and the transfer details are ready.
class InstapayReady extends InstapayInitiation {
  const InstapayReady({required this.instructions});
  final InstapayInstructions instructions;
}

/// The transfer cannot be prepared (not owner / not pending /
/// InstaPay not configured server-side).
class InstapayUnavailable extends InstapayInitiation {
  const InstapayUnavailable({required this.message, this.code});
  final String message;
  final String? code;
}
