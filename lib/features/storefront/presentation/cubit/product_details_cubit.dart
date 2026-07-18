import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';

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
  ProductDetailsCubit() : super(const DetailsState());

  /// Load a product and compute related products from the full catalog.
  void loadProduct(String id, List<Product> allProducts) {
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
  }

  void color(String value) => emit(state.copyWith(color: value));
  void length(String value) => emit(state.copyWith(length: value));
  void quantity(int value) =>
      emit(state.copyWith(quantity: value.clamp(1, state.stock).toInt()));
}
