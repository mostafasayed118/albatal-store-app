part of '../payment_cubit.dart';

// ─── Cash on Delivery ──────────────────────────────────────

extension PaymentCodFlow on PaymentCubit {
  Future<void> processCod() async {
    // Cash on Delivery — server-confirmed path.
    // The checkout creates the order BEFORE the customer picks a
    // method, so first record the COD choice server-side
    // (`set_pending_order_payment_method`, migration 037) — the
    // `confirm_cod_payment` RPC requires a COD-like stored method
    // and would otherwise reject with `payment_not_cod`.
    // The client NEVER declares success without a server response.
    emitState(state.copyWith(status: PaymentStatus.processing));

    final methodResult = await _paymentService.setOrderPaymentMethod(
      orderId: state.orderId,
      // Canonical 'cod' (037/039 allowlist) via the enum — no literals.
      method: PaymentMethod.cashOnDelivery.serverValue,
    );
    if (isClosed) return;
    if (methodResult case PaymentFailed(:final message, :final code)) {
      emitState(state.copyWith(
        status: PaymentStatus.failed,
        // Machine-readable code first so the pages' paymentMessageForCode()
        // can localize data-layer failures; null-code results keep the raw
        // message (mapper's unknown-code fallback).
        errorMessage: code ?? message,
      ));
      return;
    }

    final result = await _paymentService.confirmCodPayment(
      orderId: state.orderId,
    );
    if (isClosed) return;

    switch (result) {
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
      case PaymentPending():
        // COD confirm never returns pending (server is synchronous);
        // treat as a terminal failure instead of stranding in processing.
        emitState(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: 'payment_not_pending',
        ));
      case PaymentCancelled():
        emitState(state.copyWith(status: PaymentStatus.cancelled));
    }
  }
}
