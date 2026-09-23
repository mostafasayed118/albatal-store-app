part of '../payment_cubit.dart';

// ─── InstaPay ──────────────────────────────────────────────

extension PaymentInstapayFlow on PaymentCubit {
  Future<void> processInstapay() async {
    // InstaPay — prepare the transfer, then wait for proof upload
    // (migration 041). Method switch + amount happen server-side.
    emitState(state.copyWith(status: PaymentStatus.processing));

    final initiation = await _paymentService.initiateInstapayPayment(
      orderId: state.orderId,
    );
    if (isClosed) return;

    switch (initiation) {
      case InstapayReady(:final instructions):
        emitState(state.copyWith(
          status: PaymentStatus.awaitingProof,
          instructions: instructions,
        ));
        // The payment row stays `pending` until an admin approves
        // the submitted proof (or the 24h expiry). Subscribe to the
        // same server-authoritative status stream used for Paymob so
        // approval/rejection lands without polling.
        await startWatching(state.orderId);
      case InstapayUnavailable(:final message):
        emitState(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: message,
        ));
    }
  }
}
