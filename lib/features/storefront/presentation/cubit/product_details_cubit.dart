import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

final class DetailsState extends Equatable {
  const DetailsState({
    this.product,
    this.relatedProducts = const [],
    this.color = '',
    this.length = '',
    this.quantity = 1,
  });

  final Product? product;
  final List<Product> relatedProducts;
  final String color;
  final String length;
  final int quantity;

  /// Stock for the currently selected variant.
  int get stock => product?.stockFor(color, length) ?? 0;
  bool get inStock => stock > 0;

  DetailsState copyWith({
    Product? product,
    List<Product>? relatedProducts,
    String? color,
    String? length,
    int? quantity,
  }) =>
      DetailsState(
        product: product ?? this.product,
        relatedProducts: relatedProducts ?? this.relatedProducts,
        color: color ?? this.color,
        length: length ?? this.length,
        quantity: quantity ?? this.quantity,
      );

  @override
  List<Object?> get props =>
      [product, relatedProducts, color, length, quantity];
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
  void loadProduct(String id) async {
    final singleResult = await _catalogRepository.fetchProductById(id);
    final singleProduct = singleResult.when(
      success: (product) => product,
      failure: (_) => null,
    );
    if (singleProduct != null) {
      final allResult = await _catalogRepository.fetchProducts();
      final related = allResult.when(
        success: (all) => all
            .where((x) => x.category == singleProduct.category && x.id != singleProduct.id)
            .toList(),
        failure: (_) => <Product>[],
      );
      emit(state.copyWith(
        product: singleProduct,
        relatedProducts: related,
        color: singleProduct.colors.isNotEmpty ? singleProduct.colors.first : '',
        length: singleProduct.sizes.isNotEmpty ? singleProduct.sizes.first : '',
      ));
      return;
    }

    // Fallback to full catalog scan (legacy N+1 path) when single fetch fails.
    final result = await _catalogRepository.fetchProducts();
    result.when(
      success: (allProducts) {
        if (allProducts.isEmpty) return;
        final product = allProducts.firstWhere((x) => x.id == id,
            orElse: () => allProducts.first);
        final related = allProducts
            .where((x) => x.category == product.category && x.id != product.id)
            .toList();
        emit(state.copyWith(
          product: product,
          relatedProducts: related,
          color: product.colors.isNotEmpty ? product.colors.first : '',
          length: product.sizes.isNotEmpty ? product.sizes.first : '',
        ));
      },
      failure: (_) {},
    );
  }

  void color(String value) => emit(state.copyWith(color: value));
  void length(String value) => emit(state.copyWith(length: value));
  void quantity(int value) {
    final maxStock = state.stock > 0 ? state.stock : 99;
    emit(state.copyWith(quantity: value.clamp(1, maxStock).toInt()));
  }
}
