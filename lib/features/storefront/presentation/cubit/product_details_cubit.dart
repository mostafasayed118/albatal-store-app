import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

final class DetailsState extends Equatable {
  const DetailsState(
      {this.color = 'Emerald', this.length = '2m', this.quantity = 1});

  final String color;
  final String length;
  final int quantity;

  DetailsState copyWith({String? color, String? length, int? quantity}) =>
      DetailsState(
        color: color ?? this.color,
        length: length ?? this.length,
        quantity: quantity ?? this.quantity,
      );

  @override
  List<Object?> get props => [color, length, quantity];
}

final class ProductDetailsCubit extends Cubit<DetailsState> {
  ProductDetailsCubit() : super(const DetailsState());

  void color(String value) => emit(state.copyWith(color: value));
  void length(String value) => emit(state.copyWith(length: value));
  void quantity(int value) =>
      emit(state.copyWith(quantity: value.clamp(1, 99).toInt()));
}
