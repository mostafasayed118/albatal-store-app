import 'package:equatable/equatable.dart';

final class Product extends Equatable {
  const Product(
      {required this.id,
      required this.name,
      required this.category,
      required this.price,
      required this.imageColor,
      this.oldPrice,
      this.imageAsset,
      this.description,
      this.composition,
      this.care,
      this.origin});
  final String id, name, category;
  final double price;
  final int imageColor;
  final double? oldPrice;
  final String? imageAsset, description, composition, care, origin;
  int? get discountPercent => oldPrice == null ? null : ((1 - price / oldPrice!) * 100).round();
  @override
  List<Object?> get props =>
      [id, name, category, price, imageColor, oldPrice, imageAsset, description, composition, care, origin];
}

final class CartItem extends Equatable {
  const CartItem(
      {required this.product,
      required this.color,
      required this.length,
      this.quantity = 1});
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
