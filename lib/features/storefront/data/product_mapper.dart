import '../../../core/entities/money.dart';
import '../../../core/entities/product.dart';
import '../../../shared/services/storage_service.dart';

/// Placeholder tint used when a product row carries no image — the value the
/// network path has always written.
const _placeholderImageColor = 0xFF888888;

/// The single [Product] mapper for the storefront data layer.
///
/// Both the Supabase row path ([ProductCodec.fromRow]) and the local JSON
/// cache path ([ProductCodec.encode] / [ProductCodec.decode]) build
/// [Product] here. They used to be two hand-written constructions that
/// drifted apart: the cache path silently dropped `images`, `sizes`,
/// `colors`, `stock`, `rating` and `reviewCount`, so any product restored
/// from SharedPreferences lost them.
extension ProductCodec on Product {
  /// Builds a [Product] from a joined `products` row with `product_variants`
  /// and `product_images` embedded.
  static Product fromRow(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> variants, {
    required StorageService storageService,
  }) {
    final basePrice = row['base_price'] as int;
    final oldPriceRaw = row['old_price'] as int?;

    // Derive sizes and colors from variants.
    final sizeSet = <String>{};
    final colorSet = <String>{};
    final stockMap = <String, int>{};

    for (final v in variants) {
      final size = v['size'] as String;
      final color = v['color'] as String;
      final stock = v['stock'] as int;

      sizeSet.add(size);
      colorSet.add(color);
      stockMap['$color-$size'] = stock;
    }

    // Category name via the join.
    final category =
        (row['categories'] as Map<String, dynamic>?)?['name'] as String? ?? '';

    // TODO: add cached_network_image for Storage URLs with Cache-Control max-age=86400
    // Map product_images → imageUrls via StorageService, ordered by sort_order.
    final rawImages = row['product_images'];
    final imageRows = rawImages is List
        ? rawImages.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    imageRows.sort((a, b) {
      final sortOrderComparison = (a['sort_order'] as int? ?? 0)
          .compareTo(b['sort_order'] as int? ?? 0);
      if (sortOrderComparison != 0) {
        return sortOrderComparison;
      }
      return (a['storage_path'] as String? ?? '')
          .compareTo(b['storage_path'] as String? ?? '');
    });
    final imageUrls = imageRows
        .map((m) => m['storage_path'] as String?)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .map((p) => storageService.getProductImageUrl(p))
        .where((u) => u.isNotEmpty)
        .toList();

    return Product(
      id: row['id'] as String,
      name: row['name'] as String,
      category: category,
      price: Money(basePrice),
      oldPrice: oldPriceRaw != null ? Money(oldPriceRaw) : null,
      // imageColor is a placeholder fallback — only used when images empty.
      imageColor: _placeholderImageColor,
      images: imageUrls,
      description: row['description'] as String?,
      composition: row['composition'] as String?,
      care: row['care'] as String?,
      origin: row['origin'] as String?,
      sizes: sizeSet.toList()..sort(),
      colors: colorSet.toList()..sort(),
      stock: stockMap,
      rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: row['review_count'] as int? ?? 0,
    );
  }

  /// Serializes a [Product] to JSON for SharedPreferences.
  ///
  /// Covers every [Product] field so [decode] restores the product exactly —
  /// including the derived `images`/`sizes`/`colors`/`stock` the row mapper
  /// produces.
  static Map<String, Object?> encode(Product p) => {
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'price': p.price.minorUnits,
        'oldPrice': p.oldPrice?.minorUnits,
        'imageColor': p.imageColor,
        'imageAsset': p.imageAsset,
        'images': p.images,
        'description': p.description,
        'composition': p.composition,
        'care': p.care,
        'origin': p.origin,
        'sizes': p.sizes,
        'colors': p.colors,
        'stock': p.stock,
        'rating': p.rating,
        'reviewCount': p.reviewCount,
      };

  /// Restores a [Product] written by [encode].
  ///
  /// Missing keys fall back to the same defaults [fromRow] uses, so caches
  /// written by older builds still decode.
  static Product decode(Map<Object?, Object?> raw) => Product(
        id: raw['id'] as String,
        name: raw['name'] as String,
        category: raw['category'] as String? ?? '',
        price: Money((raw['price'] as num).toInt()),
        oldPrice: raw['oldPrice'] == null
            ? null
            : Money((raw['oldPrice'] as num).toInt()),
        imageColor:
            (raw['imageColor'] as num?)?.toInt() ?? _placeholderImageColor,
        imageAsset: raw['imageAsset'] as String?,
        images: (raw['images'] as List?)?.cast<String>() ?? const [],
        description: raw['description'] as String?,
        composition: raw['composition'] as String?,
        care: raw['care'] as String?,
        origin: raw['origin'] as String?,
        sizes: (raw['sizes'] as List?)?.cast<String>() ?? const [],
        colors: (raw['colors'] as List?)?.cast<String>() ?? const [],
        stock: (raw['stock'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            const {},
        rating: (raw['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (raw['reviewCount'] as num?)?.toInt() ?? 0,
      );
}
