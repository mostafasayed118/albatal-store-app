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

  /// Reload persisted items.
  ///
  /// By default this is a startup fill: if the user already acted
  /// (non-empty cart) a late-completing read must NOT clobber live
  /// state (live-found 2026-09-03: stale persisted items replaced
  /// fresh selections mid-checkout and the server was sent the
  /// wrong product). Pass [force] for an explicit manual refresh
  /// (e.g. the error-state retry button).
  Future<void> restore({bool force = false}) async {
    final hadItems = state.items.isNotEmpty;
    emit(state.copyWith(status: CartStatus.loading));
    final result = await _repository.readCart(_productLookup ?? (_) => null);
    switch (result) {
      case Success(:final value):
        if (force || !hadItems) {
          emit(CartState(value, status: CartStatus.ready));
        } else {
          // Keep the user's live items; just leave loading state.
          emit(state.copyWith(status: CartStatus.ready));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: CartStatus.error,
          errorMessage: error.message,
        ));
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

  /// Emit the optimistic [next] state, then await persistence and surface
  /// any failure as a follow-up error state. Persistence errors do NOT
  /// roll back the in-memory state (the user's intent is preserved for the
  /// current session) but are reported so the UI can warn that the cart
  /// won't survive a restart.
  Future<void> _emitAndPersist(CartState next) async {
    emit(next);
    final result = await _repository.writeCart(next.items);
    switch (result) {
      case Success():
        // No-op: optimistic state already emitted.
        break;
      case Failure(:final error):
        emit(next.copyWith(
          status: CartStatus.error,
          errorMessage: 'Cart may not be saved: ${error.message}',
        ));
    }
  }
}
