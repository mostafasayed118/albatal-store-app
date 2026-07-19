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

    // Vodafone Cash navigates to its own page
    if (state.selectedMethod == PaymentMethod.vodafoneCash) {
      emit(state.copyWith(status: PaymentStatus.processing));
      return;
    }

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
      case PaymentPending(:final paymentKey):
        final checkoutUrl = _getCheckoutUrl(result);
        emit(state.copyWith(
          status: PaymentStatus.awaitingVerification,
          checkoutUrl: checkoutUrl,
          transactionId: paymentKey,
        ));
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

  /// Process Vodafone Cash with phone number.
  Future<void> processVodafoneCash({required String phoneNumber}) async {
    emit(state.copyWith(status: PaymentStatus.processing));

    final result = await _paymentService.processVodafoneCash(
      amount: state.amount,
      phoneNumber: phoneNumber,
      orderId: state.orderId,
    );

    switch (result) {
      case PaymentPending(:final paymentKey):
        emit(state.copyWith(
          status: PaymentStatus.awaitingVerification,
          transactionId: paymentKey,
        ));
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

  String _getCheckoutUrl(PaymentPending result) {
    if (state.selectedMethod == PaymentMethod.paymobCard) {
      return 'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=${result.paymentKey}';
    }
    return '';
  }
}
