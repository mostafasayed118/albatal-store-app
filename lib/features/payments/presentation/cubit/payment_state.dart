import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../domain/entities/payment.dart';

/// Payment flow states — extracted from `payment_cubit.dart` (no
/// signature changes; import the cubit file, which re-exports this).
enum PaymentStatus {
  initial,
  selectingMethod,
  processing,
  awaitingVerification,
  awaitingProof,
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
    this.instructions,
  });

  final PaymentStatus status;
  final PaymentMethod? selectedMethod;
  final Money amount;
  final String orderId;
  final String? transactionId;
  final String? errorMessage;
  final String? checkoutUrl;

  /// Server-derived InstaPay transfer details while
  /// [PaymentStatus.awaitingProof].
  final InstapayInstructions? instructions;

  bool get canProceed => selectedMethod != null;

  PaymentState copyWith({
    PaymentStatus? status,
    PaymentMethod? selectedMethod,
    Money? amount,
    String? orderId,
    String? transactionId,
    String? errorMessage,
    String? checkoutUrl,
    InstapayInstructions? instructions,
  }) =>
      PaymentState(
        status: status ?? this.status,
        selectedMethod: selectedMethod ?? this.selectedMethod,
        amount: amount ?? this.amount,
        orderId: orderId ?? this.orderId,
        transactionId: transactionId ?? this.transactionId,
        errorMessage: errorMessage,
        checkoutUrl: checkoutUrl ?? this.checkoutUrl,
        instructions: instructions ?? this.instructions,
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
        instructions,
      ];
}
