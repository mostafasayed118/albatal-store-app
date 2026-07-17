import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../data/storefront_persistence.dart';
import 'products_data.dart';

final class CartState extends Equatable {
  const CartState(this.items);

  final List<CartItem> items;

  double get subtotal => items.fold(0, (value, item) => value + item.product.price * item.quantity);
  double get shipping => items.isEmpty ? 0 : 75;
  double get total => subtotal + shipping;
  int get count => items.fold(0, (value, item) => value + item.quantity);

  @override
  List<Object?> get props => [items];
}

final class CartCubit extends Cubit<CartState> {
  CartCubit(this._persistence) : super(const CartState([]));

  final StorefrontPersistence _persistence;

  Future<void> restore() async {
    final restored = await _persistence.readCart(
      (id) => products.where((product) => product.id == id).firstOrNull,
    );
    emit(CartState(restored));
  }

  void add(Product product, {String color = 'Emerald', String length = '2m', int quantity = 1}) {
    final item = CartItem(product: product, color: color, length: length, quantity: quantity);
    final old = state.items.where((existing) => existing.key == item.key).firstOrNull;
    if (old == null) {
      _emitAndPersist(CartState([...state.items, item]));
    } else {
      update(item.key, old.quantity + quantity);
    }
  }

  void update(String key, int quantity) => _emitAndPersist(CartState(
        state.items.map((item) => item.key == key ? item.copyWith(quantity: quantity.clamp(1, 99).toInt()) : item).toList(),
      ));

  void remove(String key) => _emitAndPersist(CartState(state.items.where((item) => item.key != key).toList()));

  void clear() => _emitAndPersist(const CartState([]));

  void _emitAndPersist(CartState next) {
    emit(next);
    _persistence.writeCart(next.items);
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
