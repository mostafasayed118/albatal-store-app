import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../../../shared/services/storage_service.dart';
import '../domain/entities/flash_sale.dart';
import '../domain/repositories/catalog_repository.dart';
import '../presentation/catalog_constants.dart';
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

  /// Shared product select shape (single source of truth). [fetchProducts]
  /// and [fetchProductById] must return identical column shapes — the
  /// mapper ([ProductCodec.fromRow]) is written against exactly these
  /// keys, so a divergence between the two queries would silently change
  /// the decoded product (e.g. missing images) depending on which path
  /// loaded it.
  static const _productSelect = '''
            id, name, slug, description, composition, care, origin,
            base_price, old_price, rating, review_count,
            categories!inner(name),
            product_variants(product_id, size, color, stock, price_override),
            product_images(storage_path, sort_order)
          ''';

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

  /// Loads the active product catalog.
  ///
  /// The network query is bounded to [limit] rows (audit Task 11) so a
  /// large table cannot stall the cold start — the app keeps the first
  /// ~100 products (`int limit = 100` default keeps every existing
  /// call-site compiling). `.order('name')` is kept so the bounded page
  /// is deterministic, and the offline-restore path is untouched (it
  /// reads the persistent cache, not the DB).
  @override
  Future<Result<List<Product>>> fetchProducts({int limit = 100}) async {
    // Return cached data if still fresh — avoids redundant network calls
    // while keeping the in-memory cache warm for synchronous findProductById.
    if (_cacheIsFresh) return Success(_cache!);

    try {
      // Single query with embedded variant + image relations. Supabase
      // PostgREST returns variants/images as arrays inside each product row,
      // eliminating extra round-trips.
      final rows = await _client
          .from('products')
          .select(_productSelect)
          .eq('is_active', true)
          .order('name')
          .limit(limit);

      final result = <Product>[];
      for (final row in rows) {
        final variantsRaw = row['product_variants'];
        final variants = variantsRaw is List
            ? variantsRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final product = ProductCodec.fromRow(
          row,
          variants,
          storageService: _storageService,
        );
        // Rows without a usable id/name are skipped, not fatal (audit P2).
        if (product != null) result.add(product);
      }

      _setCache(result);

      // Persist to SharedPreferences for offline fallback.
      unawaited(_persistCache(result));

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
          .map((r) => safeString(r, 'name'))
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
      final row = await _client
          .from('products')
          .select(_productSelect)
          .eq('id', id)
          .single();

      final variantsRaw = row['product_variants'];
      final variants = variantsRaw is List
          ? variantsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final product =
          ProductCodec.fromRow(row, variants, storageService: _storageService);
      // A row that came back without a usable id/name is unusable — fail
      // closed rather than handing the UI a hollow product.
      if (product == null) {
        return const Failure(AppError('Failed to load product'));
      }
      return Success(product);
    } on PostgrestException catch (e) {
      // single() throws PostgrestException (PGRST116) when no row matches.
      return Failure(AppError('Product not found', cause: e));
    } on Exception catch (e) {
      return Failure(AppError('Failed to load product', cause: e));
    }
  }

  /// Category-scoped related-products query.
  ///
  /// Filters server-side on the joined `categories.name` (inner join, so
  /// only products in [category] are returned), excludes [excludeId], and
  /// bounds the page to [limit] rows — the details strip no longer pulls
  /// the full catalog. Mapping skips unusable rows like [fetchProducts];
  /// transport errors fail closed so the cubit keeps the primary product.
  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async {
    if (category.isEmpty) return const Success(<Product>[]);
    try {
      // Filters before transforms: neq lives on the filter builder,
      // order/limit move to the transform builder (no filter ops after).
      final filtered = _client
          .from('products')
          .select(_productSelect)
          .eq('is_active', true)
          .eq('categories.name', category);
      final scoped =
          (excludeId != null && excludeId.isNotEmpty) ? filtered.neq('id', excludeId) : filtered;
      final rows = await scoped.order('name').limit(limit);

      final result = <Product>[];
      for (final row in rows) {
        final variantsRaw = row['product_variants'];
        final variants = variantsRaw is List
            ? variantsRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final product = ProductCodec.fromRow(
          row,
          variants,
          storageService: _storageService,
        );
        // Rows without a usable id/name are skipped, not fatal (audit P2).
        if (product != null) result.add(product);
      }
      return Success(result);
    } on Exception catch (e) {
      return Failure(AppError('Failed to load related products', cause: e));
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
  /// Rows are mapped via [FlashSaleCodec.fromRow]; rows without a usable
  /// `product_id` are skipped and transport errors fail closed to [Failure]
  /// (the cubit treats flash sales as non-critical and keeps the catalog).
  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async {
    try {
      final value = await _client.rpc('get_active_flash_sales');
      final rows = (value as List).whereType<Map<String, dynamic>>();
      return Success(
        rows.map(FlashSaleCodec.fromRow).whereType<FlashSale>().toList(),
      );
    } catch (e) {
      return Failure(AppError('Failed to load flash sales', cause: e));
    }
  }

  @override
  List<String> get defaultCategories => CatalogConstants.defaults;

  // ─── Persistent cache helpers ──────────────────────────────

  /// Awaitable cache write so callers can sequence on it in tests and
  /// the fire-and-forget production path marks the future [unawaited]
  /// instead of tripping `discarded_futures`.
  Future<void> _persistCache(List<Product> products) async {
    final prefs = _preferences;
    if (prefs == null) return;
    try {
      final encoded = products.map(ProductCodec.encode).toList();
      // Best-effort cache write — never crash the app over persistence.
      await prefs.setString(_persistentCacheKey, jsonEncode(encoded));
    } catch (e) {
      // Best-effort persistence — never crash the app over a cache write.
      Log.w('Catalog persistent cache write failed: $e');
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
      // Per-item fail-soft: a corrupt/tampered entry is skipped, never
      // fatal to its neighbours (previously one throwing entry discarded
      // the whole cache via the catch-all below).
      final products = <Product>[];
      for (final entry in decoded) {
        try {
          if (entry is! Map) continue;
          final product =
              ProductCodec.decode(entry as Map<Object?, Object?>);
          if (product != null) products.add(product);
        } catch (e) {
          Log.w('Catalog persistent cache skipping corrupt entry: $e');
        }
      }
      return products;
    } catch (e) {
      Log.w('Catalog persistent cache restore failed: $e');
      return null;
    }
  }

  // ─── Testing helpers ──────────────────────────────────────

  @visibleForTesting
  Future<void> persistCacheForTest(List<Product> products) =>
      _persistCache(products);

  @visibleForTesting
  List<Product>? restorePersistentCacheForTest() => _restorePersistentCache();

  @visibleForTesting
  void setCacheForTest(List<Product> products) => _setCache(products);

  @visibleForTesting
  List<Product>? get cacheForTest => _cache;
}
