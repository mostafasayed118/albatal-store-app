import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/catalog_repository.dart';

/// Supabase-backed catalog repository.
///
/// Fetches products, categories, and variants from the database so that
/// [Product.id] is always a real UUID — required by the server-side
/// `create_checkout_order` RPC which casts `product_id` to `UUID`.
///
/// Maintains both an in-memory cache (for synchronous [findProductById])
/// and a persistent SharedPreferences cache (for offline fallback when
/// the app restarts without network).
final class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository({
    SupabaseClient? client,
    SharedPreferences? preferences,
  })  : _client = client ?? Supabase.instance.client,
        _preferences = preferences;

  final SupabaseClient _client;
  final SharedPreferences? _preferences;

  /// In-memory cache of the full product list so that [findProductById]
  /// is synchronous (required by the hydration path that restores the
  /// cart from SharedPreferences without awaiting a network call).
  List<Product>? _cache;

  /// Timestamp of the last successful [fetchProducts] call. Used with
  /// [_cacheTTL] to invalidate stale data.
  DateTime? _cacheTimestamp;

  /// How long the in-memory catalog cache is considered fresh.
  static const _cacheTTL = Duration(minutes: 5);

  /// SharedPreferences key for the persistent catalog cache.
  static const _persistentCacheKey = 'catalog_products_cache_v1';

  /// Whether the cached data is still within the TTL window.
  bool get _cacheIsFresh =>
      _cache != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheTTL;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    // Return cached data if still fresh — avoids redundant network calls
    // while keeping the in-memory cache warm for synchronous findProductById.
    if (_cacheIsFresh) return Success(_cache!);

    try {
      // Single query with embedded variant relation. Supabase PostgREST
      // returns variants as an array inside each product row, eliminating
      // the second round-trip that previously fetched all variants and
      // grouped them in Dart.
      final rows = await _client.from('products').select('''
            id, name, slug, description, composition, care, origin,
            base_price, old_price, rating, review_count,
            categories!inner(name),
            product_variants(product_id, size, color, stock, price_override)
          ''').eq('is_active', true).order('name');

      final result = <Product>[];
      for (final row in rows) {
        final variantsRaw = row['product_variants'];
        final variants = variantsRaw is List
            ? variantsRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        result.add(_mapProduct(row, variants));
      }

      _cache = result;
      _cacheTimestamp = DateTime.now();

      // Persist to SharedPreferences for offline fallback.
      _persistCache(result);

      return Success(result);
    } on Exception catch (e) {
      // On network failure, try persistent cache first (survives app restart),
      // then fall back to in-memory cache (same session only).
      final persistentCache = _restorePersistentCache();
      if (persistentCache != null) {
        _cache = persistentCache;
        _cacheTimestamp = DateTime.now();
        return Success(persistentCache);
      }
      final stale = _cache;
      if (stale != null) return Success(stale);
      return Failure(AppError('Failed to load products', cause: e));
    }
  }

  @override
  Future<Result<List<String>>> fetchCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select('name')
          .eq('is_active', true)
          .order('sort_order');

      final names = rows
          .map((r) => r['name'] as String)
          .where((n) => n.isNotEmpty)
          .toList();

      return Success(names);
    } on Exception catch (e) {
      return Failure(AppError('Failed to load categories', cause: e));
    }
  }

  @override
  Product? findProductById(String id) {
    // Fast path: check the cache populated by fetchProducts.
    final cached = _cache;
    if (cached != null) {
      for (final p in cached) {
        if (p.id == id) return p;
      }
    }
    // Cache miss — this should not happen in normal flow because
    // fetchProducts() is always called first. Return null so the
    // hydration path can skip the missing product gracefully.
    return null;
  }

  @override
  List<String> get defaultCategories => const [
        'Silk',
        'Cotton',
        'Velvet',
        'Linen',
        'Wool',
      ];

  // ─── Persistent cache helpers ──────────────────────────────

  void _persistCache(List<Product> products) {
    final prefs = _preferences;
    if (prefs == null) return;
    try {
      final encoded = products
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'category': p.category,
                'price': p.price.minorUnits,
                'oldPrice': p.oldPrice?.minorUnits,
                'description': p.description,
                'composition': p.composition,
                'care': p.care,
                'origin': p.origin,
                'sizes': p.sizes,
                'colors': p.colors,
                'stock': p.stock,
                'rating': p.rating,
                'reviewCount': p.reviewCount,
                'imageColor': p.imageColor,
                'imageAsset': p.imageAsset,
              })
          .toList();
      prefs.setString(_persistentCacheKey, jsonEncode(encoded));
    } catch (_) {
      // Best-effort persistence — never crash the app over a cache write.
    }
  }

  List<Product>? _restorePersistentCache() {
    final prefs = _preferences;
    if (prefs == null) return null;
    try {
      final raw = prefs.getString(_persistentCacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => Product(
                id: m['id'] as String,
                name: m['name'] as String,
                category: m['category'] as String? ?? '',
                price: Money((m['price'] as num).toInt()),
                oldPrice: m['oldPrice'] != null
                    ? Money((m['oldPrice'] as num).toInt())
                    : null,
                imageColor: (m['imageColor'] as num?)?.toInt() ?? 0xFF888888,
                imageAsset: m['imageAsset'] as String?,
                description: m['description'] as String?,
                composition: m['composition'] as String?,
                care: m['care'] as String?,
                origin: m['origin'] as String?,
                sizes: (m['sizes'] as List?)?.cast<String>() ?? const [],
                colors: (m['colors'] as List?)?.cast<String>() ?? const [],
                stock: (m['stock'] as Map<String, dynamic>?)
                        ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
                    const {},
                rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
                reviewCount: (m['reviewCount'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─── Mapping helpers ────────────────────────────────────────

  static Product _mapProduct(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> variants,
  ) {
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

    return Product(
      id: row['id'] as String,
      name: row['name'] as String,
      category: category,
      price: Money(basePrice),
      oldPrice: oldPriceRaw != null ? Money(oldPriceRaw) : null,
      // imageColor and imageAsset are presentation-layer concerns not
      // stored in the database. Use defaults so the product card renders.
      imageColor: 0xFF888888,
      description: row['description'] as String?,
      composition: row['composition'] as String?,
      care: row['care'] as String?,
      origin: row['origin'] as String?,
      sizes: sizeSet.toList(),
      colors: colorSet.toList(),
      stock: stockMap,
      rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: row['review_count'] as int? ?? 0,
    );
  }
}
