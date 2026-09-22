import 'package:flutter/material.dart';

import '../../domain/paymob_url_guard.dart';
import '../widgets/checkout_body.dart';
import '../widgets/invalid_checkout_body.dart';

/// Web view for Paymob hosted checkout.
///
/// Instead of parsing the WebView callback URL (which can be spoofed),
/// the [PaymentCubit] subscribes to the `payments` table through
/// [PaymentService.watchPaymentStatus]. The webhook
/// (`/paymob-callback`) updates the payment status server-side; the
/// cubit detects the update and emits a terminal [PaymentStatus].
///
/// This page intentionally does NOT depend on [PaymentCubit]: the cubit
/// is scoped to `/payment-method` (which stays alive underneath this
/// pushed route). [PaymentMethodPage]'s `BlocConsumer` reacts to
/// terminal states — popping this WebView on failure/cancel/timeout
/// and navigating to order-success on success — so the checkout page
/// never needs to read the cubit from its own (sibling) route context.
/// This keeps the trust boundary explicit and avoids a
/// `ProviderNotFoundException` after `context.push`.
///
/// Bodies live in `widgets/` (one widget per file): [CheckoutBody],
/// [InvalidCheckoutBody].
class PaymobCheckoutPage extends StatelessWidget {
  const PaymobCheckoutPage({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  Widget build(BuildContext context) {
    final isSafeUrl = PaymobUrlGuard.isSafePaymobCheckoutUrl(checkoutUrl);
    return isSafeUrl
        ? CheckoutBody(checkoutUrl: checkoutUrl)
        : const InvalidCheckoutBody();
  }
}
