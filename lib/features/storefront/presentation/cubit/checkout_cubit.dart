import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/address.dart';

enum CheckoutStatus { initial, placing, success, error }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.payment = 'Credit Card',
    this.address,
    this.errorMessage,
  });

  final CheckoutStatus status;
  final String payment;
  final Address? address;
  final String? errorMessage;

  String get addressName => address?.name ?? 'Ahmed Mansour';
  String get addressLine =>
      address != null
          ? '${address!.street}, ${address!.city}'
          : '12 El Tahrir Street, Cairo, Egypt';

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
    Address? address,
    String? errorMessage,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        payment: payment ?? this.payment,
        address: address ?? this.address,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, payment, address, errorMessage];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit() : super(const CheckoutState());

  void payment(String value) => emit(state.copyWith(payment: value));

  void setAddress(Address address) => emit(state.copyWith(address: address));

  Future<void> place() async {
    emit(state.copyWith(status: CheckoutStatus.placing));
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      emit(state.copyWith(status: CheckoutStatus.success));
    } catch (e) {
      emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: 'Failed to place order'));
    }
  }
}
