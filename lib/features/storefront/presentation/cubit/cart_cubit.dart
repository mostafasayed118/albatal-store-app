import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/iterable_x.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../data/products_data.dart';

enum CartStatus { initial, loading, ready, error }

final class CartState extends Equatable {
  const CartState(
    this.items, {
    this.status = CartStatus.initial,
    this.errorMessage,
  });

  final List<CartItem> items;
  final CartStatus status;
  final String? errorMessage;

  double get subtotal => items.fold(
      0, (value, item) => value + item.product.price * item.quantity);
  double get shipping => items.isEmpty ? 0 : 75;
  double get total => subtotal + shipping;
  int get count => items.fold(0, (value, item) => value + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    CartStatus? status,
    String? errorMessage,
  }) =>
      CartState(
        items ?? this.items,
        status: status ?? this.status,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [items, status, errorMessage];
}

final class CartCubit extends Cubit<CartState> {
  CartCubit(this._repository) : super(const CartState([]));

  final CartRepository _repository;

  Future<void> restore() async {
    emit(state.copyWith(status: CartStatus.loading));
    try {
      final restored = await _repository.readCart(
        (id) => products.where((product) => product.id == id).firstOrNull,
      );
      emit(CartState(restored, status: CartStatus.ready));
    } catch (e) {
      emit(state.copyWith(
          status: CartStatus.error, errorMessage: 'Failed to load cart'));
    }
  }

  void add(Product product,
      {String color = 'Emerald', String length = '2m', int quantity = 1}) {
    final item = CartItem(
        product: product, color: color, length: length, quantity: quantity);
    final old =
        state.items.where((existing) => existing.key == item.key).firstOrNull;
    if (old == null) {
      _emitAndPersist(
          CartState([...state.items, item], status: CartStatus.ready));
    } else {
      update(item.key, old.quantity + quantity);
    }
  }

  void update(String key, int quantity) => _emitAndPersist(CartState(
        state.items
            .map((item) => item.key == key
                ? item.copyWith(quantity: quantity.clamp(1, 99).toInt())
                : item)
            .toList(),
        status: CartStatus.ready,
      ));

  void remove(String key) => _emitAndPersist(CartState(
      state.items.where((item) => item.key != key).toList(),
      status: CartStatus.ready));

  void clear() =>
      _emitAndPersist(const CartState([], status: CartStatus.ready));

  void _emitAndPersist(CartState next) {
    emit(next);
    _repository.writeCart(next.items);
  }
}
