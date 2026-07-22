import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_service.dart';

// ─── States ────────────────────────────────────────────────

enum PaymentStatus {
  initial,
  selectingMethod,
  processing,
  awaitingVerification,
  success,
  failed,
  cancelled,
  expired,
  timedOut,
}

final class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.initial,
    this.selectedMethod,
    this.amount = Money.zero,
    this.orderId = '',
    this.transactionId,
    this.errorMessage,
    this.checkoutUrl,
  });

  final PaymentStatus status;
  final PaymentMethod? selectedMethod;
  final Money amount;
  final String orderId;
  final String? transactionId;
  final String? errorMessage;
  final String? checkoutUrl;

  bool get canProceed => selectedMethod != null;

  PaymentState copyWith({
    PaymentStatus? status,
    PaymentMethod? selectedMethod,
    Money? amount,
    String? orderId,
    String? transactionId,
    String? errorMessage,
    String? checkoutUrl,
  }) =>
      PaymentState(
        status: status ?? this.status,
        selectedMethod: selectedMethod ?? this.selectedMethod,
        amount: amount ?? this.amount,
        orderId: orderId ?? this.orderId,
        transactionId: transactionId ?? this.transactionId,
        errorMessage: errorMessage,
        checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      );

  @override
  List<Object?> get props => [
        status,
        selectedMethod,
        amount,
        orderId,
        transactionId,
        errorMessage,
        checkoutUrl,
      ];
}

// ─── Cubit ─────────────────────────────────────────────────

class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(this._paymentService,
      {Duration watchTimeout = _defaultWatchTimeout})
      : _watchTimeout = watchTimeout,
        super(const PaymentState());

  /// How long the client waits for the server-authoritative payment
  /// status before declaring [PaymentStatus.timedOut]. The order
  /// itself expires server-side after 15 minutes (migration 011),
  /// so the client watch is capped at the same horizon. A timeout
  /// never declares success — it only surfaces a recoverable
  /// "still processing / please retry" state.
  static const _defaultWatchTimeout = Duration(minutes: 15);

  final Duration _watchTimeout;

  final PaymentService _paymentService;
  StreamSubscription<PaymentResult>? _watchSubscription;
  Timer? _watchTimeoutTimer;

  /// Initialize payment for an order.
  void initPayment({required Money amount, required String orderId}) {
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
  /// Guards against re-entry while a payment is already in flight to
  /// prevent double-initiation of Paymob orders.
  Future<void> processPayment({required String customerEmail}) async {
    if (state.selectedMethod == null) return;
    if (state.status == PaymentStatus.processing) return;

    // Cash on Delivery — server-confirmed path.
    // The client calls `confirm_cod_payment` RPC which atomically
    // marks the payment as success and the order as paid. The client
    // NEVER declares success without a server response.
    if (state.selectedMethod == PaymentMethod.cashOnDelivery) {
      emit(state.copyWith(status: PaymentStatus.processing));

      final result = await _paymentService.confirmCodPayment(
        orderId: state.orderId,
      );

      switch (result) {
        case PaymentSuccess(:final transactionId):
          emit(state.copyWith(
            status: PaymentStatus.success,
            transactionId: transactionId,
          ));
        case PaymentFailed(:final message):
          emit(state.copyWith(
            status: PaymentStatus.failed,
            errorMessage: message,
          ));
        case PaymentPending():
        case PaymentCancelled():
          break;
      }
      return;
    }

    // Paymob Card — initiate payment
    emit(state.copyWith(status: PaymentStatus.processing));

    final result = await _paymentService.initiatePayment(
      amount: state.amount,
      method: state.selectedMethod!,
      orderId: state.orderId,
      customerEmail: customerEmail,
    );

    switch (result) {
      case PaymentPending(:final checkoutUrl):
        emit(state.copyWith(
          status: PaymentStatus.awaitingVerification,
          checkoutUrl: checkoutUrl,
        ));
        // The Paymob hosted checkout is now open in a WebView. Subscribe
        // to the server-side payment status so we detect the webhook's
        // update without parsing the callback URL (which can be spoofed).
        await startWatching(state.orderId);
      case PaymentSuccess(:final transactionId):
        emit(state.copyWith(
          status: PaymentStatus.success,
          transactionId: transactionId,
        ));
      case PaymentFailed(:final message):
        emit(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: message,
        ));
      case PaymentCancelled():
        emit(state.copyWith(status: PaymentStatus.cancelled));
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
        errorMessage: 'A valid order reference is required to verify payment.',
      ));
      return;
    }

    _watchTimeoutTimer = Timer(_watchTimeout, _handleWatchTimeout);

    _watchSubscription = _paymentService.watchPaymentStatus(orderId).listen(
      (result) {
        if (isClosed || state.status != PaymentStatus.awaitingVerification) {
          return;
        }
        switch (result) {
          case PaymentSuccess(:final transactionId):
            _complete(state.copyWith(
              status: PaymentStatus.success,
              transactionId: transactionId,
            ));
          case PaymentFailed(:final message):
            _complete(state.copyWith(
              status: PaymentStatus.failed,
              errorMessage: message,
            ));
          case PaymentPending():
          case PaymentCancelled():
            break;
        }
      },
      onError: (_, __) {
        if (isClosed || state.status != PaymentStatus.awaitingVerification) {
          return;
        }
        _complete(state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: 'Unable to verify payment status. Please try again.',
        ));
      },
    );
  }

  /// Fires the verification timeout without waiting fifteen minutes.
  ///
  /// This is intentionally public for deterministic Flutter tests; production
  /// code relies on the timer created by [startWatching].
  Future<void> fireWatchTimeoutForTest() async {
    _handleWatchTimeout();
  }

  void _handleWatchTimeout() {
    if (isClosed || state.status != PaymentStatus.awaitingVerification) {
      return;
    }
    _complete(state.copyWith(
      status: PaymentStatus.timedOut,
      errorMessage:
          'Payment verification timed out. Please check your orders before retrying.',
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
