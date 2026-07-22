import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

enum DetailsStatus { loading, ready, error }

final class DetailsState extends Equatable {
  const DetailsState({
    this.status = DetailsStatus.loading,
    this.product,
    this.relatedProducts = const [],
    this.color = '',
    this.length = '',
    this.quantity = 1,
    this.errorMessage,
  });

  final DetailsStatus status;
  final Product? product;
  final List<Product> relatedProducts;
  final String color;
  final String length;
  final int quantity;
  final String? errorMessage;

  int get stock => product?.stockFor(color, length) ?? 0;
  bool get inStock => stock > 0;

  DetailsState copyWith({
    DetailsStatus? status,
    Product? product,
    List<Product>? relatedProducts,
    String? color,
    String? length,
    int? quantity,
    String? errorMessage,
    bool clearProduct = false,
  }) =>
      DetailsState(
        status: status ?? this.status,
        product: clearProduct ? null : (product ?? this.product),
        relatedProducts: relatedProducts ?? this.relatedProducts,
        color: color ?? this.color,
        length: length ?? this.length,
        quantity: quantity ?? this.quantity,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props =>
      [status, product, relatedProducts, color, length, quantity, errorMessage];
}

final class ProductDetailsCubit extends Cubit<DetailsState> {
  ProductDetailsCubit(this._catalogRepository) : super(const DetailsState());

  final CatalogRepository _catalogRepository;
  String? _lastLoadedId;

  void loadProduct(String id) {
    _lastLoadedId = id;
    emit(state.copyWith(
      status: DetailsStatus.loading,
      clearProduct: true,
      errorMessage: null,
    ));
    _fetch(id);
  }

  void retry() {
    if (_lastLoadedId != null) {
      emit(state.copyWith(
        status: DetailsStatus.loading,
        clearProduct: true,
        errorMessage: null,
      ));
      _fetch(_lastLoadedId!);
    }
  }

  Future<void> _fetch(String id) async {
    final result = await _catalogRepository.fetchProducts();
    if (_lastLoadedId != id) return;

    result.when(
      success: (allProducts) {
        if (allProducts.isEmpty) {
          emit(state.copyWith(
            status: DetailsStatus.error,
            errorMessage: 'Catalog is empty',
          ));
          return;
        }
        final product = allProducts.firstWhere(
          (x) => x.id == id,
          orElse: () => allProducts.first,
        );
        final related = allProducts
            .where((x) => x.category == product.category && x.id != product.id)
            .toList();
        emit(state.copyWith(
          status: DetailsStatus.ready,
          product: product,
          relatedProducts: related,
          color: product.colors.isNotEmpty ? product.colors.first : '',
          length: product.sizes.isNotEmpty ? product.sizes.first : '',
          errorMessage: null,
        ));
      },
      failure: (error) {
        emit(state.copyWith(
          status: DetailsStatus.error,
          errorMessage: error.message,
        ));
      },
    );
  }

  void color(String value) => emit(state.copyWith(color: value));
  void length(String value) => emit(state.copyWith(length: value));
  void quantity(int value) {
    final maxStock = state.stock > 0 ? state.stock : 99;
    emit(state.copyWith(quantity: value.clamp(1, maxStock).toInt()));
  }
}
