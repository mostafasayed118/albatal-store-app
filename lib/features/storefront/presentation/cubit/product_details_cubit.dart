import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/services/logger.dart';
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

  /// Generation counter against A→B clobber: every [loadProduct] call
  /// bumps it, and each async continuation bails when its generation is
  /// stale — a slow related-fetch for product A can no longer overwrite
  /// product B's ready state after rapid navigation.
  int _generation = 0;

  /// Load a product by id from the catalog repository.
  ///
  /// First attempts a single-row [fetchProductById] query (1 query, not N).
  /// Falls back to the full [fetchProducts] scan if the single fetch fails.
  /// Related products come from the category-scoped [fetchRelated] query —
  /// never the full catalog pull.
  Future<void> loadProduct(String id) async {
    final generation = ++_generation;
    emit(const DetailsState(status: DetailsStatus.loading));

    try {
      final singleResult = await _catalogRepository.fetchProductById(id);
      if (generation != _generation) return;
      final singleProduct = singleResult.when(
        success: (product) => product,
        failure: (_) => null,
      );
      if (singleProduct != null) {
        var related = <Product>[];
        try {
          final relatedResult = await _catalogRepository.fetchRelated(
            singleProduct.category,
            excludeId: singleProduct.id,
          );
          if (generation != _generation) return;
          related = relatedResult.when(
            success: (items) => items,
            failure: (_) => <Product>[],
          );
        } catch (e) {
          Log.w('Product details related fetch failed: $e');
          related = <Product>[];
        }
        if (generation != _generation) return;
        emit(_readyState(singleProduct, related));
        return;
      }

      // Retain the legacy full-catalog fallback, but only accept the requested id.
      final result = await _catalogRepository.fetchProducts();
      if (generation != _generation) return;
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
    } catch (e) {
      if (generation != _generation) return;
      Log.w('Product details load failed: $e');
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

  void color(String value) {
    // Reject values outside the loaded product's variant set (stale chips
    // from a previous product must not silently select nothing).
    final colors = state.product?.colors;
    if (colors != null && colors.isNotEmpty && !colors.contains(value)) return;
    emit(state.copyWith(color: value));
  }

  void length(String value) {
    final sizes = state.product?.sizes;
    if (sizes != null && sizes.isNotEmpty && !sizes.contains(value)) return;
    emit(state.copyWith(length: value));
  }

  void quantity(int value) {
    // Out-of-stock variants pin to 1: the old `stock > 0 ? stock : 99`
    // fallback opened a 1..99 range for a variant that cannot be bought.
    final stock = state.stock;
    if (stock <= 0) {
      if (state.quantity != 1) emit(state.copyWith(quantity: 1));
      return;
    }
    emit(state.copyWith(quantity: value.clamp(1, stock).toInt()));
  }
}
