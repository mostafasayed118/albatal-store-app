import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

final class CheckoutState extends Equatable {
  const CheckoutState({this.step = 0, this.payment = 'Credit Card', this.placing = false});

  final int step;
  final String payment;
  final bool placing;

  CheckoutState copyWith({int? step, String? payment, bool? placing}) => CheckoutState(
        step: step ?? this.step,
        payment: payment ?? this.payment,
        placing: placing ?? this.placing,
      );

  @override
  List<Object?> get props => [step, payment, placing];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit() : super(const CheckoutState());

  void payment(String value) => emit(state.copyWith(payment: value));

  Future<void> place() async {
    emit(state.copyWith(placing: true));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    emit(state.copyWith(placing: false, step: 2));
  }
}
