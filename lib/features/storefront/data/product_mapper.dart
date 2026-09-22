import '../../../core/entities/money.dart';
import '../../../core/entities/product.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/storage_service.dart';
import '../domain/entities/flash_sale.dart';

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
  /// Shared product select shape (single source of truth). The list and
  /// single-row queries must return identical column shapes — [fromRow]
  /// is written against exactly these keys, so a divergence between the
  /// two queries would silently change the decoded product (e.g. missing
  /// images) depending on which path loaded it.
  static const productSelect = '''
            id, name, slug, description, composition, care, origin,
            base_price, old_price, rating, review_count,
            categories!inner(name),
            product_variants(product_id, size, color, stock, price_override),
            product_images(storage_path, sort_order)
          ''';

  /// Builds a [Product] from a joined `products` row with `product_variants`
  /// and `product_images` embedded.
  ///
  /// Total decode (audit P2): every field degrades to the entity default
  /// instead of throwing, so one malformed row can never crash the whole
  /// catalog load. Rows without a usable `id` or `name` return null —
  /// callers skip them (same contract as [FlashSaleCodec.fromRow]).
  ///
  /// Product images resolve to width-bounded render URLs (audit P0-4):
  /// [Product.imageAsset] carries the primary at the grid budget and
  /// [Product.images] the whole list at the detail budget.
  static Product? fromRow(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> variants, {
    required StorageService storageService,
  }) {
    final id = safeString(row, 'id');
    final name = safeString(row, 'name');
    if (id.isEmpty || name.isEmpty) return null;

    final basePrice = safeInt(row, 'base_price');
    final oldPrice = optInt(row, 'old_price');

    // Derive sizes and colors from variants. Malformed variant rows are
    // skipped rather than throwing into the repository.
    final sizeSet = <String>{};
    final colorSet = <String>{};
    final stockMap = <String, int>{};

    for (final v in variants) {
      final size = safeString(v, 'size');
      final color = safeString(v, 'color');
      if (size.isEmpty || color.isEmpty) continue;
      sizeSet.add(size);
      colorSet.add(color);
      stockMap['$color-$size'] = safeInt(v, 'stock');
    }

    // Category name via the join.
    final category = safeString(safeMap(row['categories']), 'name');

    // Width-bounded render URLs (audit 2026-09-14 P0-4). Storage serves the
    // downsized variant instead of the full upload, with one budget per
    // surface class because a single image feeds two very different
    // consumers:
    //   • cards + thumbnails  → [Product.imageAsset], the primary image at
    //     `StorageService.gridImageWidth` (420) — grid card, flash-sale row,
    //     hero, related/cart/wishlist thumbnails.
    //   • detail gallery/zoom → [Product.images], every image at
    //     `StorageService.detailImageWidth` (720). Zoom shares this list, so a
    //     product's photos are fetched once and never at original resolution.
    // The bare public URL survives only as the fail-open fallback INSIDE the
    // width helper: a path with no renderable extension still renders.
    // Rendering is cached in the presentation layer — `ProductImageResolver`
    // / `AppImage` wrap `CachedNetworkImage` for every remote product image.
    // Map product_images → imageUrls via StorageService, ordered by sort_order.
    // The uploaded objects carry a one-year cache lifetime
    // (`StorageService.productImageCacheSeconds`), which is safe precisely
    // because a replaced image lands on a fresh UUID path, never over the old
    // one — so a long-lived cache entry can never go stale.
    final rawImages = row['product_images'];
    final imageRows = rawImages is List
        ? rawImages.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    imageRows.sort((a, b) {
      final sortOrderComparison =
          safeInt(a, 'sort_order').compareTo(safeInt(b, 'sort_order'));
      if (sortOrderComparison != 0) {
        return sortOrderComparison;
      }
      return safeString(a, 'storage_path')
          .compareTo(safeString(b, 'storage_path'));
    });
    final imagePaths = imageRows
        .map((m) => m['storage_path'])
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();
    final imageUrls = imagePaths
        .map((p) => storageService.getProductImageUrlForWidth(
              p,
              StorageService.detailImageWidth,
            ))
        .where((u) => u.isNotEmpty)
        .toList();
    // The list/card media source: the primary (lowest `sort_order`) image at
    // the grid budget. Null when no usable image exists, so every card keeps
    // its swatch-only fallback.
    final primaryImage = imagePaths.isEmpty
        ? null
        : storageService.getProductImageUrlForWidth(
            imagePaths.first,
            StorageService.gridImageWidth,
          );

    final ratingRaw = row['rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;

    return Product(
      id: id,
      name: name,
      category: category,
      price: Money(basePrice),
      oldPrice: oldPrice == null ? null : Money(oldPrice),
      // imageColor is a placeholder fallback — only used when images empty.
      imageColor: _placeholderImageColor,
      imageAsset: primaryImage,
      images: imageUrls,
      description: optString(row, 'description'),
      composition: optString(row, 'composition'),
      care: optString(row, 'care'),
      widthCm: optInt(row, 'width_cm'),
      gsm: optInt(row, 'gsm'),
      sellByLength: (row['sell_by_length'] as bool?) ?? false,
      minCutMeters: optDouble(row, 'min_cut_meters'),
      origin: optString(row, 'origin'),
      sizes: sizeSet.toList()..sort(),
      colors: colorSet.toList()..sort(),
      colorName: optString(row, 'color_name'),
      stock: stockMap,
      rating: rating,
      reviewCount: safeInt(row, 'review_count'),
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
        'widthCm': p.widthCm,
        'gsm': p.gsm,
        'sellByLength': p.sellByLength,
        'minCutMeters': p.minCutMeters,
        'origin': p.origin,
        'sizes': p.sizes,
        'colors': p.colors,
        'colorName': p.colorName,
        'stock': p.stock,
        'rating': p.rating,
        'reviewCount': p.reviewCount,
      };

  /// Restores a [Product] written by [encode].
  ///
  /// Missing keys fall back to the same defaults [fromRow] uses, so caches
  /// written by older builds still decode. Total decode (audit P2): a
  /// corrupt/tampered cache entry degrades field-by-field instead of
  /// throwing; entries without a usable `id` return null so callers skip
  /// them.
  static Product? decode(Map<Object?, Object?> raw) {
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    // Total decode: mistyped cache values degrade instead of throwing
    // (one bad entry never fails the whole restore).
    List<String> optStrList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    final priceRaw = raw['price'];
    final oldPriceRaw = raw['oldPrice'];
    final imageColorRaw = raw['imageColor'];
    final ratingRaw = raw['rating'];
    final reviewRaw = raw['reviewCount'];
    return Product(
        id: id,
        name: safeString(raw, 'name'),
        category: safeString(raw, 'category'),
        price: Money(priceRaw is num ? priceRaw.toInt() : 0),
        oldPrice: oldPriceRaw is num ? Money((oldPriceRaw).toInt()) : null,
        imageColor: imageColorRaw is num
            ? imageColorRaw.toInt()
            : _placeholderImageColor,
        imageAsset: optString(raw, 'imageAsset'),
        images: optStrList(raw['images']),
        description: optString(raw, 'description'),
        composition: optString(raw, 'composition'),
        care: optString(raw, 'care'),
        widthCm: optInt(raw, 'widthCm'),
        gsm: optInt(raw, 'gsm'),
        sellByLength:
            raw['sellByLength'] is bool ? raw['sellByLength'] as bool : false,
        minCutMeters: optDouble(raw, 'minCutMeters'),
        origin: optString(raw, 'origin'),
        sizes: optStrList(raw['sizes']),
        colors: optStrList(raw['colors']),
        colorName: optString(raw, 'colorName'),
        stock: safeMap(raw['stock']).map(
          (k, v) => MapEntry(k, v is num ? v.toInt() : 0),
        ),
        rating: ratingRaw is num ? ratingRaw.toDouble() : 0.0,
        reviewCount: reviewRaw is num ? reviewRaw.toInt() : 0);
  }

  /// Maps product rows to [Product], skipping rows without a usable
  /// id/name (audit P2) — the shared loop for the list, related, and
  /// single-row paths so all three decode identically.
  static List<Product> listFromRows(
    Iterable<dynamic> rows, {
    required StorageService storageService,
  }) {
    final result = <Product>[];
    for (final row in rows) {
      final variantsRaw = row['product_variants'];
      final variants = variantsRaw is List
          ? variantsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final product = ProductCodec.fromRow(
        row,
        variants,
        storageService: storageService,
      );
      // Rows without a usable id/name are skipped, not fatal (audit P2).
      if (product != null) result.add(product);
    }
    return result;
  }
}

/// Codec for flash-sale rows from the `get_active_flash_sales` RPC.
///
/// All parsing is total: rows without a usable `product_id` return `null`
/// (callers skip them) and every other malformed value degrades to the
/// entity default — a bad row never throws into the cubit.
extension FlashSaleCodec on FlashSale {
  static FlashSale? fromRow(Map<String, dynamic> row) {
    final productId = row['product_id'];
    if (productId is! String || productId.isEmpty) return null;

    final discountRaw = row['discount_pct'] ?? row['discountPct'];
    final discountPct = discountRaw is int
        ? discountRaw
        : (discountRaw is num
            ? discountRaw.toInt()
            : FlashSale.defaultDiscountPct);

    final endsRaw = row['ends_at'] ?? row['endsAt'] ?? row['end_at'];
    final endsAt = endsRaw is DateTime
        ? endsRaw
        : (endsRaw is String ? DateTime.tryParse(endsRaw) : null);

    return FlashSale(
      productId: productId,
      discountPct: discountPct,
      endsAt: endsAt,
    );
  }
}
