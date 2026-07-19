import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/iterable_x.dart';
import '../../domain/repositories/cart_repository.dart';

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

  Money get subtotal =>
      items.fold(Money.zero, (value, item) => value + item.lineTotal);
  Money get shipping => items.isEmpty ? Money.zero : Money.egp(75);
  Money get total => subtotal + shipping;
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
  CartCubit(this._repository, {ProductLookup? productLookup})
      : _productLookup = productLookup,
        super(const CartState([]));

  final CartRepository _repository;

  /// Resolves a product id to a [Product] when restoring the cart.
  /// Injected from outside (e.g. the catalog) so this presentation cubit
  /// never imports a data file directly. May be null when the catalog
  /// isn't available yet (e.g. tests); restore then loads items as-is.
  final ProductLookup? _productLookup;

  Future<void> restore() async {
    emit(state.copyWith(status: CartStatus.loading));
    try {
      final restored = await _repository.readCart(
        _productLookup ?? (_) => null,
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
