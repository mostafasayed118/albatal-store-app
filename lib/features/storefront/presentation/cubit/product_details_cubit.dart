import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

enum DetailsStatus { initial, loading, ready, notFound, error }

final class DetailsState extends Equatable {
  const DetailsState({
    this.status = DetailsStatus.initial,
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

  /// Stock for the currently selected variant.
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
  }) =>
      DetailsState(
        status: status ?? this.status,
        product: product ?? this.product,
        relatedProducts: relatedProducts ?? this.relatedProducts,
        color: color ?? this.color,
        length: length ?? this.length,
        quantity: quantity ?? this.quantity,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [
        status,
        product,
        relatedProducts,
        color,
        length,
        quantity,
        errorMessage,
      ];
}

final class ProductDetailsCubit extends Cubit<DetailsState> {
  ProductDetailsCubit(this._catalogRepository) : super(const DetailsState());

  final CatalogRepository _catalogRepository;

  /// Load a product by id from the catalog repository.
  ///
  /// First attempts a single-row [fetchProductById] query (1 query, not N).
  /// Falls back to the full [fetchProducts] scan if the single fetch fails.
  /// Related products are still derived via [fetchProducts] filtering — at
  /// least the single product fetch is now 1 query not N.
  Future<void> loadProduct(String id) async {
    emit(const DetailsState(status: DetailsStatus.loading));

    try {
      final singleResult = await _catalogRepository.fetchProductById(id);
      final singleProduct = singleResult.when(
        success: (product) => product,
        failure: (_) => null,
      );
      if (singleProduct != null) {
        var related = <Product>[];
        try {
          final allResult = await _catalogRepository.fetchProducts();
          related = allResult.when(
            success: (all) => all
                .where((x) =>
                    x.category == singleProduct.category &&
                    x.id != singleProduct.id)
                .toList(),
            failure: (_) => <Product>[],
          );
        } catch (_) {
          related = <Product>[];
        }
        emit(_readyState(singleProduct, related));
        return;
      }

      // Retain the legacy full-catalog fallback, but only accept the requested id.
      final result = await _catalogRepository.fetchProducts();
      result.when(
        success: (allProducts) {
          final matches = allProducts.where((x) => x.id == id);
          final product = matches.isEmpty ? null : matches.first;
          if (product == null) {
            emit(const DetailsState(status: DetailsStatus.notFound));
            return;
          }
          final related = allProducts
              .where(
                  (x) => x.category == product.category && x.id != product.id)
              .toList();
          emit(_readyState(product, related));
        },
        failure: (_) => emit(const DetailsState(
          status: DetailsStatus.error,
          errorMessage: 'Unable to load product details.',
        )),
      );
    } catch (_) {
      emit(const DetailsState(
        status: DetailsStatus.error,
        errorMessage: 'Unable to load product details.',
      ));
    }
  }

  DetailsState _readyState(Product product, List<Product> related) =>
      DetailsState(
        status: DetailsStatus.ready,
        product: product,
        relatedProducts: related,
        color: product.colors.isNotEmpty ? product.colors.first : '',
        length: product.sizes.isNotEmpty ? product.sizes.first : '',
      );

  void color(String value) => emit(state.copyWith(color: value));
  void length(String value) => emit(state.copyWith(length: value));
  void quantity(int value) {
    final maxStock = state.stock > 0 ? state.stock : 99;
    emit(state.copyWith(quantity: value.clamp(1, maxStock).toInt()));
  }
}
