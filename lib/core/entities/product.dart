import 'package:equatable/equatable.dart';

import 'money.dart';

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
    this.widthCm,
    this.gsm,
    this.sellByLength = false,
    this.minCutMeters,
    this.sizes = const ['1m', '2m', '5m'],
    this.colors = const ['Emerald', 'Gold', 'Ivory'],
    this.colorName,
    this.stock = const {},
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  final String id, name, category;
  final Money price;
  final int imageColor;
  final Money? oldPrice;
  final String? imageAsset, description, composition, care, origin;

  /// Fabric roll width in cm (feature-batch §10), null = not specified.
  final int? widthCm;

  /// Fabric weight in grams per square meter (§10).
  final int? gsm;

  /// When true the shopper picks a custom cut length (0.5 m steps,
  /// clamped to [minCutMeters]) instead of fixed sizes (§10). The
  /// metered line is validated server-side by the 051 proposal.
  final bool sellByLength;
  final double? minCutMeters;
  final List<String> images;
  final List<String> sizes;
  final List<String> colors;

  /// Curated display color name from `products.color_name` (AUD-011,
  /// migration 062). Null when the row does not carry one — filters keep
  /// using the variant-derived [colors]; this is the DB-derived source for
  /// future swatch/filter wiring.
  final String? colorName;
  final Map<String, int> stock;
  final double rating;
  final int reviewCount;

  int? get discountPercent {
    final original = oldPrice;
    if (original == null || original.minorUnits == 0) return null;
    final pct = ((1 - price.minorUnits / original.minorUnits) * 100).round();
    // Clamp negative discounts (price above oldPrice) to zero — a
    // negative "discount" never displays.
    return pct < 0 ? 0 : pct;
  }

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
        widthCm,
        gsm,
        sellByLength,
        minCutMeters,
        sizes,
        colors,
        colorName,
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
    this.sample = false,
  });

  final Product product;
  final String color, length;
  final int quantity;

  /// Sample/swatch line (Wave C): a small cut with a fixed low/zero
  /// server price. The flag flows through cart persistence and into
  /// the checkout payload (`sample: true`); server-side price
  /// enforcement is a pending supabase/ follow-up, so clients must
  /// treat the line estimate as zero, never as the catalog price.
  final bool sample;

  CartItem copyWith({int? quantity, bool? sample}) => CartItem(
      product: product,
      color: color,
      length: length,
      quantity: quantity ?? this.quantity,
      sample: sample ?? this.sample);

  String get key =>
      sample ? '${product.id}-$color-sample' : '${product.id}-$color-$length';

  /// Line total = unit price × quantity. For sell-by-length meters and
  /// sample lines, use the storefront `CartItemPricing.effectiveLineTotal`
  /// extension — this stays the plain fixed-size math (zero schema churn
  /// for existing lines).
  Money get lineTotal => product.price * quantity;

  @override
  List<Object?> get props => [product, color, length, quantity, sample];
}
