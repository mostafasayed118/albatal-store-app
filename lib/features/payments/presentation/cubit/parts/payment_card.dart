part of '../payment_cubit.dart';

// ─── Paymob Card ───────────────────────────────────────────

extension PaymentCardFlow on PaymentCubit {
  Future<void> processCard({required String customerEmail}) async {
    emitState(state.copyWith(status: PaymentStatus.processing));

    final methodResult = await _paymentService.setOrderPaymentMethod(
      orderId: state.orderId,
      method: PaymentMethod.paymobCard.serverValue,
    );
    if (isClosed) return;
    if (methodResult case PaymentFailed(:final message, :final code)) {
      emitState(state.copyWith(
        status: PaymentStatus.failed,
        errorMessage: code ?? message,
      ));
      return;
    }

    final result = await _paymentService.initiatePayment(
      amount: state.amount,
      method: state.selectedMethod!,
      orderId: state.orderId,
      customerEmail: customerEmail,
    );
    if (isClosed) return;

    switch (result) {
      case PaymentPending(:final checkoutUrl):
        // Trust-boundary: only open Paymob-owned HTTPS checkout URLs
        // (PaymobUrlGuard). A mistyped/proxied URL fails closed instead
        // of opening attacker-controlled content in the WebView.
        if (!PaymobUrlGuard.isSafePaymobCheckoutUrl(checkoutUrl)) {
          emitState(state.copyWith(
            status: PaymentStatus.failed,
            errorMessage: 'network_error',
          ));
          return;
        }
        emitState(state.copyWith(
          status: PaymentStatus.awaitingVerification,
          checkoutUrl: checkoutUrl,
        ));
        // The Paymob hosted checkout is now open in a WebView. Subscribe
        // to the server-side payment status so we detect the webhook's
        // update without parsing the callback URL (which can be spoofed).
        await startWatching(state.orderId);
      case PaymentSuccess(:final transactionId):
        emitState(state.copyWith(
          status: PaymentStatus.success,
          transactionId: transactionId,
        ));
      case PaymentFailed(:final message, :final code):
        emitState(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: code ?? message,
        ));
      case PaymentCancelled():
        emitState(state.copyWith(status: PaymentStatus.cancelled));
    }
  }
}
