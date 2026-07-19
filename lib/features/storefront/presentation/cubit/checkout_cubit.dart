import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../storefront/data/checkout_service.dart';

enum CheckoutStatus { initial, creatingOrder, placing, success, error }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.payment = 'Credit Card',
    this.selectedAddress,
    this.errorMessage,
    this.pendingOrderId,
    this.serverTotal,
    this.expiresAt,
  });

  final CheckoutStatus status;
  final String payment;
  final Address? selectedAddress;
  final String? errorMessage;
  final String? pendingOrderId;
  final Money? serverTotal;
  final DateTime? expiresAt;

  bool get hasAddress => selectedAddress != null;
  bool get hasPendingOrder => pendingOrderId != null && serverTotal != null;

  /// Step index for the checkout progress indicator (0=Shipping, 1=Payment, 2=Confirm).
  int get step => switch (status) {
        CheckoutStatus.initial => 0,
        CheckoutStatus.creatingOrder => 1,
        CheckoutStatus.placing => 2,
        CheckoutStatus.success => 2,
        CheckoutStatus.error => 1,
      };

  CheckoutState copyWith({
    CheckoutStatus? status,
    String? payment,
    Address? selectedAddress,
    bool clearAddress = false,
    String? errorMessage,
    String? pendingOrderId,
    Money? serverTotal,
    DateTime? expiresAt,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        payment: payment ?? this.payment,
        selectedAddress:
            clearAddress ? null : (selectedAddress ?? this.selectedAddress),
        errorMessage: errorMessage,
        pendingOrderId: pendingOrderId ?? this.pendingOrderId,
        serverTotal: serverTotal ?? this.serverTotal,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  @override
  List<Object?> get props => [
        status,
        payment,
        selectedAddress,
        errorMessage,
        pendingOrderId,
        serverTotal,
        expiresAt,
      ];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._checkoutService) : super(const CheckoutState());

  final CheckoutService _checkoutService;

  void payment(String value) => emit(state.copyWith(payment: value));

  void selectAddress(Address address) =>
      emit(state.copyWith(selectedAddress: address));

  void clearAddress() => emit(state.copyWith(clearAddress: true));

  /// Create a pending order via the server-side checkout Edge Function.
  ///
  /// Returns the order_id and the server-computed total so the payment layer
  /// can initiate Paymob with the real order id and amount. The order is
  /// created as "pending" — the paymob-callback webhook promotes it to
  /// "paid" on success, or cancels + restores stock on failure.
  ///
  /// For cash-on-delivery, the order remains "pending" until an admin
  /// advances it (or it expires after 15 minutes).
  Future<void> createPendingOrder({
    required List<CartItem> cartItems,
    String? idempotencyKey,
  }) async {
    emit(state.copyWith(status: CheckoutStatus.creatingOrder));
    try {
      final result = await _checkoutService.placeOrder(
        items: cartItems,
        paymentMethod: state.payment,
        addressSnapshot: state.selectedAddress != null
            ? {
                'id': state.selectedAddress!.id,
                'recipient': state.selectedAddress!.recipient,
                'line': state.selectedAddress!.line,
                'city': state.selectedAddress!.city,
                'country': state.selectedAddress!.country,
              }
            : {},
        idempotencyKey: idempotencyKey,
      );

      result.when(
        success: (pending) => emit(state.copyWith(
          status: CheckoutStatus.placing,
          pendingOrderId: pending.orderId,
          serverTotal: pending.total,
          expiresAt: pending.expiresAt,
        )),
        failure: (error) => emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: error.message,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Failed to create order: $e',
      ));
    }
  }

  void markSuccess() => emit(state.copyWith(status: CheckoutStatus.success));
  void markError(String message) =>
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: message));
}
