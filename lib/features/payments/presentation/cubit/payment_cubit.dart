import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/entities/money.dart';
import '../../domain/entities/payment.dart';
import '../../domain/paymob_url_guard.dart';
import '../../domain/repositories/payment_service.dart';
import 'payment_state.dart';

export 'payment_state.dart';

part 'parts/payment_card.dart';
part 'parts/payment_cod.dart';
part 'parts/payment_instapay.dart';

// --- Cubit ---

class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(this._paymentService,
      {Duration watchTimeout = _defaultWatchTimeout,
      Timer Function(Duration duration, void Function() callback)?
          timerFactory})
      : _watchTimeout = watchTimeout,
        _timerFactory = timerFactory ?? _realTimer,
        super(const PaymentState());

  static Timer _realTimer(Duration duration, void Function() callback) =>
      Timer(duration, callback);

  /// How long the client waits for the server-authoritative payment
  /// status before declaring [PaymentStatus.timedOut]. The order
  /// itself expires server-side after 15 minutes (migration 011),
  /// so the client watch is capped at the same horizon. A timeout
  /// never declares success — it only surfaces a recoverable
  /// "still processing / please retry" state.
  static const _defaultWatchTimeout = Duration(minutes: 15);

  final Duration _watchTimeout;
  final Timer Function(Duration duration, void Function() callback)
      _timerFactory;

  final PaymentService _paymentService;
  // ignore: cancel_subscriptions - cancelled in _stopWatching/_complete/close
  StreamSubscription<PaymentResult>? _watchSubscription;
  Timer? _watchTimeoutTimer;

  /// Public state transition for part-file extensions ([emit] is
  /// @protected and only callable from instance members).
  void emitState(PaymentState nextState) => emit(nextState);

  /// Initialize payment for an order.
  ///
  /// Stops any prior server-status watch first so a re-init never leaks
  /// the previous order's subscription/timer.
  void initPayment({required Money amount, required String orderId}) {
    unawaited(_stopWatching());
    emit(PaymentState(
      status: PaymentStatus.selectingMethod,
      amount: amount,
      orderId: orderId,
    ));
  }

  /// Select a payment method.
  void selectMethod(PaymentMethod method) {
    emit(state.copyWith(selectedMethod: method));
  }

  /// Start payment processing.
  ///
  /// Guards against double-entry: if a COD RPC or card initiation is
  /// already in flight, subsequent calls are silently ignored. The UI
  /// button is also disabled during [PaymentStatus.processing], but
  /// this guard protects against programmatic re-entry.
  Future<void> processPayment({required String customerEmail}) async {
    if (state.selectedMethod == null) return;
    if (state.status == PaymentStatus.processing) return;
    // Block re-initiation while a checkout session is already open or a
    // proof is pending review — a second initiation would orphan the
    // first session's watch.
    if (state.status == PaymentStatus.awaitingVerification) return;
    if (state.status == PaymentStatus.awaitingProof) return;
    if (state.selectedMethod == PaymentMethod.cashOnDelivery) {
      return processCod();
    }
    if (state.selectedMethod == PaymentMethod.instapay) {
      return processInstapay();
    }
    return processCard(customerEmail: customerEmail);
  }

  /// Submit the transfer proof while [PaymentStatus.awaitingProof].
  ///
  /// The status STAYS [PaymentStatus.awaitingProof] for the whole
  /// upload — flipping to `processing` would make the status watcher
  /// drop a server event that arrives mid-upload. Re-entrancy is
  /// prevented by the caller (the page disables its upload button
  /// while a submission is in flight).
  ///
  /// Returns true when the proof was recorded. The payment remains
  /// `pending` server-side until admin review (or the 24h expiry).
  Future<bool> submitInstapayProof({
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
  }) async {
    if (state.status != PaymentStatus.awaitingProof) return false;

    final result = await _paymentService.submitInstapayProof(
      orderId: state.orderId,
      proofBytes: proofBytes,
      fileExt: fileExt,
      reference: reference,
    );
    if (isClosed) return false;

    switch (result) {
      case PaymentSuccess():
        return true;
      case PaymentFailed(:final message, :final code):
        emit(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: code ?? message,
        ));
        return false;
      case PaymentPending():
      case PaymentCancelled():
        return false;
    }
  }

  /// Mark payment as cancelled by user.
  ///
  /// This only ends the client wait. It never changes the provider or server
  /// payment state; Paymob's verified callback remains authoritative.
  void cancel() {
    unawaited(_stopWatching());
    emit(state.copyWith(status: PaymentStatus.cancelled));
  }

  /// Reset to initial state.
  void reset() {
    unawaited(_stopWatching());
    emit(const PaymentState());
  }

  /// Subscribe to server-side payment status updates via Realtime.
  ///
  /// The repository ([PaymentService.watchPaymentStatus]) owns the
  /// Supabase Realtime channel and DB row parsing; the cubit only
  /// consumes the typed [PaymentResult] stream and translates terminal
  /// outcomes into terminal [PaymentStatus] values. The subscription and
  /// timeout are cancelled on terminal events or in [close].
  Future<void> startWatching(String orderId) async {
    await _stopWatching();
    if (orderId.trim().isEmpty) {
      emit(state.copyWith(
        status: PaymentStatus.failed,
        errorMessage: 'order_ref_required',
      ));
      return;
    }

    _watchTimeoutTimer = _timerFactory(_watchTimeout, _handleWatchTimeout);

    _watchSubscription = _paymentService.watchPaymentStatus(orderId).listen(
      (result) {
        if (isClosed ||
            (state.status != PaymentStatus.awaitingVerification &&
                state.status != PaymentStatus.awaitingProof)) {
          return;
        }
        switch (result) {
          case PaymentSuccess(:final transactionId):
            _complete(state.copyWith(
              status: PaymentStatus.success,
              transactionId: transactionId,
            ));
          case PaymentFailed(:final message, :final code):
            _complete(state.copyWith(
              status: PaymentStatus.failed,
              errorMessage: code ?? message,
            ));
          case PaymentPending():
            break;
          case PaymentCancelled():
            // Server-driven terminal (cancelled/expired rows via the
            // watcher). Ends the client wait; never changes server state.
            _complete(state.copyWith(
              status: PaymentStatus.cancelled,
            ));
        }
      },
      onError: (_, __) {
        // Intentionally awaitingVerification-only: an error while
        // awaitingProof must not flip the proof-upload state to failed
        // (pinned by payment_test.dart); the 24h InstaPay review window
        // outlives the 15min card watch, so the proof state survives
        // transient realtime errors and keeps polling.
        if (isClosed || state.status != PaymentStatus.awaitingVerification) {
          return;
        }
        _complete(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: 'verify_failed',
        ));
      },
    );
  }

  void _handleWatchTimeout() {
    // Intentionally awaitingVerification-only: InstaPay proof review
    // (24h expiry) outlives the 15min card watch, so awaitingProof
    // never times out here — the server expiry drives it.
    if (isClosed || state.status != PaymentStatus.awaitingVerification) {
      return;
    }
    _complete(state.copyWith(
      status: PaymentStatus.timedOut,
      errorMessage: 'verify_timeout',
    ));
  }

  void _complete(PaymentState nextState) {
    _watchTimeoutTimer?.cancel();
    _watchTimeoutTimer = null;
    final subscription = _watchSubscription;
    _watchSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    emit(nextState);
  }

  Future<void> _stopWatching() async {
    _watchTimeoutTimer?.cancel();
    _watchTimeoutTimer = null;
    final subscription = _watchSubscription;
    _watchSubscription = null;
    await subscription?.cancel();
  }

  @override
  Future<void> close() async {
    await _stopWatching();
    return super.close();
  }
}
