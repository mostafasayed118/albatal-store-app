import 'package:equatable/equatable.dart';

final class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageColor,
    this.oldPrice,
    this.imageAsset,
    this.images = const [],
    this.description,
    this.composition,
    this.care,
    this.origin,
    this.sizes = const ['1m', '2m', '5m'],
    this.colors = const ['Emerald', 'Gold', 'Ivory'],
    this.stock = const {},
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  final String id, name, category;
  final double price;
  final int imageColor;
  final double? oldPrice;
  final String? imageAsset, description, composition, care, origin;
  final List<String> images;
  final List<String> sizes;
  final List<String> colors;
  final Map<String, int> stock;
  final double rating;
  final int reviewCount;

  int? get discountPercent =>
      oldPrice == null ? null : ((1 - price / oldPrice!) * 100).round();

  /// Stock for a specific variant key like "Emerald-2m".
  int stockFor(String color, String length) => stock['$color-$length'] ?? 0;

  bool get inStock => stock.values.any((v) => v > 0);

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        price,
        imageColor,
        oldPrice,
        imageAsset,
        images,
        description,
        composition,
        care,
        origin,
        sizes,
        colors,
        stock,
        rating,
        reviewCount,
      ];
}

final class CartItem extends Equatable {
  const CartItem({
    required this.product,
    required this.color,
    required this.length,
    this.quantity = 1,
  });

  final Product product;
  final String color, length;
  final int quantity;

  CartItem copyWith({int? quantity}) => CartItem(
      product: product,
      color: color,
      length: length,
      quantity: quantity ?? this.quantity);

  String get key => '${product.id}-$color-$length';

  @override
  List<Object?> get props => [product, color, length, quantity];
}
