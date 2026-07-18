import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../widgets/address_form.dart';

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.step = 0,
    this.payment = 'Credit Card',
    this.placing = false,
    this.address,
  });

  final int step;
  final String payment;
  final bool placing;
  final Address? address;

  /// Returns the display address, falling back to the mock default.
  String get addressName => address?.name ?? 'Ahmed Mansour';
  String get addressLine =>
      address != null
          ? '${address!.street}, ${address!.city}'
          : '12 El Tahrir Street, Cairo, Egypt';

  CheckoutState copyWith({
    int? step,
    String? payment,
    bool? placing,
    Address? address,
  }) =>
      CheckoutState(
        step: step ?? this.step,
        payment: payment ?? this.payment,
        placing: placing ?? this.placing,
        address: address ?? this.address,
      );

  @override
  List<Object?> get props => [step, payment, placing, address];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit() : super(const CheckoutState());

  void payment(String value) => emit(state.copyWith(payment: value));

  void setAddress(Address address) => emit(state.copyWith(address: address));

  Future<void> place() async {
    emit(state.copyWith(placing: true));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    emit(state.copyWith(placing: false, step: 2));
  }
}
