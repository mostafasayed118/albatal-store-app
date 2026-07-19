import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/wishlist_repository.dart';

enum WishlistStatus { initial, loading, ready, error }

final class WishlistState extends Equatable {
  const WishlistState({
    this.status = WishlistStatus.initial,
    this.ids = const {},
    this.products = const [],
    this.errorMessage,
  });

  final WishlistStatus status;
  final Set<String> ids;
  final List<Product> products;
  final String? errorMessage;

  bool contains(String id) => ids.contains(id);

  WishlistState copyWith({
    WishlistStatus? status,
    Set<String>? ids,
    List<Product>? products,
    String? errorMessage,
  }) =>
      WishlistState(
        status: status ?? this.status,
        ids: ids ?? this.ids,
        products: products ?? this.products,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, ids, products, errorMessage];
}

final class WishlistCubit extends Cubit<WishlistState> {
  WishlistCubit(this._repository) : super(const WishlistState());

  final WishlistRepository _repository;

  Future<void> restore() async {
    emit(state.copyWith(status: WishlistStatus.loading));
    final result = await _repository.readWishlist();
    switch (result) {
      case Success(:final value):
        emit(WishlistState(ids: value, status: WishlistStatus.ready));
      case Failure(:final error):
        emit(state.copyWith(
          status: WishlistStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Resolve wishlist IDs against the product catalog.
  void resolveProducts(List<Product> allProducts) {
    final matched = allProducts.where((p) => state.ids.contains(p.id)).toList();
    emit(state.copyWith(products: matched));
  }

  void toggle(String id) {
    final next = {...state.ids}..toggle(id);
    emit(WishlistState(ids: next, status: WishlistStatus.ready));
    _repository.writeWishlist(next);
  }
}

extension WishlistToggle on Set<String> {
  void toggle(String value) {
    contains(value) ? remove(value) : add(value);
  }
}
