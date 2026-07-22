import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
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

  /// Debounce timer for SharedPreferences writes. Rapid quantity changes
  /// (e.g. tapping +/- quickly) batch into a single write instead of
  /// hammering disk on every mutation.
  Timer? _persistTimer;

  /// Whether a persistence flush is needed on disposal.
  bool _pendingPersist = false;

  Future<void> restore() async {
    emit(state.copyWith(status: CartStatus.loading));
    final result = await _repository.readCart(_productLookup ?? (_) => null);
    switch (result) {
      case Success(:final value):
        emit(CartState(value, status: CartStatus.ready));
      case Failure(:final error):
        emit(state.copyWith(
          status: CartStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  void add(Product product,
      {String color = 'Emerald', String length = '2m', int quantity = 1}) {
    final stock = product.stockFor(color, length);
    final clampedQuantity = quantity.clamp(0, stock);
    if (clampedQuantity <= 0) {
      return;
    }
    final item = CartItem(
        product: product,
        color: color,
        length: length,
        quantity: clampedQuantity);
    final old =
        state.items.where((existing) => existing.key == item.key).firstOrNull;
    if (old == null) {
      _emitAndPersist(
          CartState([...state.items, item], status: CartStatus.ready));
    } else {
      final newQuantity = (old.quantity + clampedQuantity).clamp(1, stock);
      update(item.key, newQuantity);
    }
  }

  void update(String key, int quantity) {
    final item = state.items.firstWhere((i) => i.key == key, orElse: () {
      throw StateError('CartItem with key $key not found');
    });
    final stock = item.product.stockFor(item.color, item.length);
    _emitAndPersist(CartState(
      state.items
          .map((i) => i.key == key
              ? i.copyWith(quantity: quantity.clamp(1, stock).toInt())
              : i)
          .toList(),
      status: CartStatus.ready,
    ));
  }

  void remove(String key) => _emitAndPersist(CartState(
      state.items.where((item) => item.key != key).toList(),
      status: CartStatus.ready));

  void clear() =>
      _emitAndPersist(const CartState([], status: CartStatus.ready));

  void _emitAndPersist(CartState next) {
    emit(next);
    _pendingPersist = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () {
      _pendingPersist = false;
      _repository.writeCart(next.items);
    });
  }

  @override
  Future<void> close() async {
    _persistTimer?.cancel();
    if (_pendingPersist) {
      _pendingPersist = false;
      await _repository.writeCart(state.items);
    }
    super.close();
  }
}
