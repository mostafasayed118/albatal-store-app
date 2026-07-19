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
  PaymentCubit(this._paymentService) : super(const PaymentState());

  final PaymentService _paymentService;
  StreamSubscription<PaymentResult>? _watchSubscription;

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
  Future<void> processPayment({required String customerEmail}) async {
    if (state.selectedMethod == null) return;

    // Cash on Delivery — direct success
    if (state.selectedMethod == PaymentMethod.cashOnDelivery) {
      emit(state.copyWith(status: PaymentStatus.processing));
      emit(state.copyWith(
        status: PaymentStatus.success,
        transactionId: 'COD-${DateTime.now().millisecondsSinceEpoch}',
      ));
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
      case PaymentPending(:final paymentKey, :final checkoutUrl):
        emit(state.copyWith(
          status: PaymentStatus.awaitingVerification,
          checkoutUrl: checkoutUrl,
          transactionId: paymentKey,
        ));
        // The Paymob hosted checkout is now open in a WebView. Subscribe
        // to the server-side payment status so we detect the webhook's
        // update without parsing the callback URL (which can be spoofed).
        startWatching(state.orderId);
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

  /// Handle payment callback from web view.
  Future<void> handleCallback(String callbackData) async {
    final result = await _paymentService.verifyPayment(callbackData);

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
      default:
        break;
    }
  }

  /// Mark payment as cancelled by user.
  void cancel() => emit(state.copyWith(status: PaymentStatus.cancelled));

  /// Reset to initial state.
  void reset() => emit(const PaymentState());

  /// Subscribe to server-side payment status updates via Realtime.
  ///
  /// The repository ([PaymentService.watchPaymentStatus]) owns the
  /// Supabase Realtime channel and DB row parsing; the cubit only
  /// consumes the typed [PaymentResult] stream and translates terminal
  /// outcomes into [PaymentStatus.success] / [PaymentStatus.failed].
  /// The subscription is cancelled on terminal events or in [close].
  Future<void> startWatching(String orderId) async {
    await _watchSubscription?.cancel();
    _watchSubscription = _paymentService.watchPaymentStatus(orderId).listen(
      (result) {
        switch (result) {
          case PaymentSuccess(:final transactionId):
            emit(state.copyWith(
              status: PaymentStatus.success,
              transactionId: transactionId,
            ));
            _watchSubscription?.cancel();
          case PaymentFailed(:final message):
            emit(state.copyWith(
              status: PaymentStatus.failed,
              errorMessage: message,
            ));
            _watchSubscription?.cancel();
          case PaymentPending():
          case PaymentCancelled():
            break;
        }
      },
    );
  }

  @override
  Future<void> close() {
    _watchSubscription?.cancel();
    return super.close();
  }
}
