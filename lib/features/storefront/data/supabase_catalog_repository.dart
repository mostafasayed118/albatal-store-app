import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../shared/services/storage_service.dart';
import '../domain/repositories/catalog_repository.dart';
import 'product_mapper.dart';

/// Supabase-backed catalog repository.
///
/// Fetches products, categories, and variants from the database so that
/// [Product.id] is always a real UUID — required by the server-side
/// `create_checkout_order` RPC which casts `product_id` to `UUID`.
///
/// Maintains both an in-memory cache (for synchronous [findProductById])
/// and a persistent SharedPreferences cache (for offline fallback when
final class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository({
    SupabaseClient? client,
    SharedPreferences? preferences,
    StorageService? storageService,
  })  : _client = client ?? Supabase.instance.client,
        _preferences = preferences,
        _storageService = storageService ??
            StorageService(client: client ?? Supabase.instance.client);

  final SupabaseClient _client;
  final SharedPreferences? _preferences;
  final StorageService _storageService;

  /// In-memory cache of the full product list so that [findProductById]
  /// is synchronous (required by the hydration path that restores the
  /// cart from SharedPreferences without awaiting a network call).
  List<Product>? _cache;

  /// Id → Product index over [_cache] so [findProductById] is O(1) instead
  /// of a linear scan per cart line during hydration. Rebuilt — never
  /// mutated in place — by [_setCache], the single choke point for cache
  /// writes (network fetch, offline restore, and the test helper all
  /// route through it, so the map can never drift from the list).
  final Map<String, Product> _productsById = {};

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

  /// Atomically replaces the in-memory cache and rebuilds the id index.
  /// If [products] contains duplicate ids the last entry wins.
  void _setCache(List<Product> products) {
    _cache = products;
    _cacheTimestamp = DateTime.now();
    _productsById
      ..clear()
      ..addEntries(products.map((p) => MapEntry(p.id, p)));
  }

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    // Return cached data if still fresh — avoids redundant network calls
    // while keeping the in-memory cache warm for synchronous findProductById.
    if (_cacheIsFresh) return Success(_cache!);

    try {
      // Single query with embedded variant + image relations. Supabase
      // PostgREST returns variants/images as arrays inside each product row,
      // eliminating extra round-trips.
      final rows = await _client.from('products').select('''
            id, name, slug, description, composition, care, origin,
            base_price, old_price, rating, review_count,
            categories!inner(name),
            product_variants(product_id, size, color, stock, price_override),
            product_images(storage_path, sort_order)
          ''').eq('is_active', true).order('name');

      final result = <Product>[];
      for (final row in rows) {
        final variantsRaw = row['product_variants'];
        final variants = variantsRaw is List
            ? variantsRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        result.add(ProductCodec.fromRow(
          row,
          variants,
          storageService: _storageService,
        ));
      }

      _setCache(result);

      // Persist to SharedPreferences for offline fallback.
      _persistCache(result);

      return Success(result);
    } on Exception catch (e) {
      // On network failure, try persistent cache first (survives app restart),
      // then fall back to in-memory cache (same session only).
      final persistentCache = _restorePersistentCache();
      if (persistentCache != null) {
        _setCache(persistentCache);
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
  Future<Result<Product>> fetchProductById(String id) async {
    // O(1) cache fast path — avoids network when fetchProducts() already
    // warmed the cache.
    final cached = _productsById[id];
    if (cached != null) return Success(cached);

    try {
      final row = await _client.from('products').select('''
            id, name, slug, description, composition, care, origin,
            base_price, old_price, rating, review_count,
            categories!inner(name),
            product_variants(product_id, size, color, stock, price_override),
            product_images(storage_path, sort_order)
          ''').eq('id', id).single();

      final variantsRaw = row['product_variants'];
      final variants = variantsRaw is List
          ? variantsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final product =
          ProductCodec.fromRow(row, variants, storageService: _storageService);
      return Success(product);
    } on PostgrestException catch (e) {
      // single() throws PostgrestException (PGRST116) when no row matches.
      return Failure(AppError('Product not found', cause: e));
    } on Exception catch (e) {
      return Failure(AppError('Failed to load product', cause: e));
    }
  }

  @override
  Product? findProductById(String id) {
    // O(1) map lookup over the cache populated by fetchProducts.
    final hit = _productsById[id];
    if (hit != null) return hit;
    // Cache miss — this should not happen in normal flow because
    // fetchProducts() is always called first. Return null so the
    // hydration path can skip the missing product gracefully.
    return null;
  }

  /// Fetches currently active flash sales via `get_active_flash_sales` RPC.
  ///
  /// Returns a list of raw JSON rows — UI can map to domain as needed.
  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() =>
      _client.rpc('get_active_flash_sales').then(
            (value) => (value as List).cast<Map<String, dynamic>>(),
          );

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
      final encoded = products.map(ProductCodec.encode).toList();
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
          .map(ProductCodec.decode)
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─── Testing helpers ──────────────────────────────────────

  @visibleForTesting
  void persistCacheForTest(List<Product> products) => _persistCache(products);

  @visibleForTesting
  List<Product>? restorePersistentCacheForTest() => _restorePersistentCache();

  @visibleForTesting
  void setCacheForTest(List<Product> products) => _setCache(products);

  @visibleForTesting
  List<Product>? get cacheForTest => _cache;
}
