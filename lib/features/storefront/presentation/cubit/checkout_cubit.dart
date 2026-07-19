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
    this.orderId,
    this.totalCents,
  });

  final CheckoutStatus status;
  final String payment;
  final Address? selectedAddress;
  final String? errorMessage;
  final String? orderId;
  final Money? totalCents;

  bool get hasAddress => selectedAddress != null;

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
    String? orderId,
    Money? totalCents,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        payment: payment ?? this.payment,
        selectedAddress:
            clearAddress ? null : (selectedAddress ?? this.selectedAddress),
        errorMessage: errorMessage,
        orderId: orderId ?? this.orderId,
        totalCents: totalCents ?? this.totalCents,
      );

  @override
  List<Object?> get props => [
        status,
        payment,
        selectedAddress,
        errorMessage,
        orderId,
        totalCents,
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
  /// Returns the order_id and total_cents so the payment layer can
  /// initiate Paymob payment. The order is created as "pending" —
  /// it will be promoted to "paid" by the webhook on success, or
  /// cancelled + stock restored on failure.
  Future<void> createPendingOrder({
    required List<CartItem> cartItems,
    required Money cartTotal,
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
      );

      result.when(
        success: (order) => emit(state.copyWith(
          status: CheckoutStatus.placing,
          orderId: order.id,
          totalCents: order.total,
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
