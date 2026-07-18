import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/address.dart';

enum CheckoutStatus { initial, placing, success, error }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.payment = 'Credit Card',
    this.selectedAddress,
    this.errorMessage,
  });

  final CheckoutStatus status;
  final String payment;
  final Address? selectedAddress;
  final String? errorMessage;

  bool get hasAddress => selectedAddress != null;

  /// Step index for the checkout progress indicator (0=Shipping, 1=Payment, 2=Confirm).
  int get step => switch (status) {
        CheckoutStatus.initial => 0,
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
  }) =>
      CheckoutState(
        status: status ?? this.status,
        payment: payment ?? this.payment,
        selectedAddress:
            clearAddress ? null : (selectedAddress ?? this.selectedAddress),
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, payment, selectedAddress, errorMessage];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit() : super(const CheckoutState());

  void payment(String value) => emit(state.copyWith(payment: value));

  void selectAddress(Address address) =>
      emit(state.copyWith(selectedAddress: address));

  void clearAddress() => emit(state.copyWith(clearAddress: true));

  Future<void> place() async {
    emit(state.copyWith(status: CheckoutStatus.placing));
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      emit(state.copyWith(status: CheckoutStatus.success));
    } catch (e) {
      emit(state.copyWith(
          status: CheckoutStatus.error, errorMessage: 'Failed to place order'));
    }
  }
}
