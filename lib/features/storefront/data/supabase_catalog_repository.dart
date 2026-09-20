import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/failure_codes.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../../../shared/services/storage_service.dart';
import '../domain/entities/flash_sale.dart';
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
    required SupabaseClient client,
    SharedPreferences? preferences,
    StorageService? storageService,
  })  : _client = client,
        _preferences = preferences,
        _storageService = storageService ?? StorageService(client: client);

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

  /// Default page size for [fetchProducts].
  ///
  /// KNOWN CEILING: search, category/color/price filtering and sorting all
  /// run client-side over the fetched page (`CatalogState.visible`), so any
  /// product beyond this bound is invisible to the storefront UI — an
  /// unbounded catalog is silently truncated. The value is large enough for
  /// the seeded catalog and the full-page case is logged as a truncation
  /// signal; raising it or moving search server-side is the owner's call
  /// (see `docs/perf-budget.md`).
  static const kCatalogPageSize = 100;

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
  /// large table cannot stall the cold start — default [kCatalogPageSize].
  /// `.order('name')` is kept so the bounded page is deterministic, the
  /// offline-restore path is untouched (it reads the persistent cache, not
  /// the DB), and hitting the bound logs a truncation warning because all
  /// client-side search/filter/sort operate on this page only.
  @override
  Future<Result<List<Product>>> fetchProducts(
      {int limit = kCatalogPageSize}) async {
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

      // Truncation signal: `fetchProducts` is bounded, and every
      // search/filter/sort pass runs CLIENT-side over this page, so a full
      // page means the catalog has outgrown the bound and results are
      // silently incomplete. Logged (not thrown) so the storefront keeps
      // working while the owner decides between a larger page and
      // server-side search — see the note on [_catalogPageSize].
      if (result.length >= limit) {
        Log.w(
          'Catalog page is full ($limit rows): client-side search/filter '
          'cannot see products beyond this page.',
        );
      }

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
      return Failure(
          AppError('Failed to load products', cause: e, code: kFailureLoad));
    }
  }

  @override
  Future<Result<List<String>>> fetchCategories() => Result.guard(() async {
        final rows = await _client
            .from('categories')
            .select('name')
            .eq('is_active', true)
            .order('sort_order');
        return rows
            .map((r) => safeString(r, 'name'))
            .where((n) => n.isNotEmpty)
            .toList();
      }, 'Failed to load categories');

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
        return const Failure(
            AppError('Failed to load product', code: kFailureLoad));
      }
      return Success(product);
    } on PostgrestException catch (e) {
      // single() throws PostgrestException (PGRST116) when no row matches.
      return Failure(
          AppError('Product not found', cause: e, code: kFailureNotFound));
    } on Exception catch (e) {
      // Offline cold start (Task #8): the in-memory index missed and the
      // network is gone. Restore the persistent cache once — a deep link
      // to a previously synced product still resolves from disk.
      final restored = _restorePersistentCache();
      if (restored != null) {
        _setCache(restored);
        final hit = _productsById[id];
        if (hit != null) return Success(hit);
      }
      return Failure(
          AppError('Failed to load product', cause: e, code: kFailureLoad));
    }
  }

  /// Category-scoped related-products query.
  ///
  /// Filters server-side on the joined `categories.name` (inner join, so
  /// only products in [category] are returned), excludes [excludeId], and
  /// bounds the page to [limit] rows — the details strip no longer pulls
  /// the full catalog. Mapping skips unusable rows like [fetchProducts];
  /// transport errors degrade to a cache-derived strip (in-memory, else
  /// the persistent snapshot) and fail closed only when nothing is
  /// cached, so the cubit keeps the primary product either way.
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
      final scoped = (excludeId != null && excludeId.isNotEmpty)
          ? filtered.neq('id', excludeId)
          : filtered;
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
      // Offline degrade (Task #8): the related strip should not go blank
      // when a full catalog snapshot exists — derive the strip from the
      // in-memory cache, restoring the persistent cache on a cold start.
      var pool = _cache;
      if (pool == null) {
        final restored = _restorePersistentCache();
        if (restored != null) {
          _setCache(restored);
          pool = restored;
        }
      }
      if (pool != null) {
        return Success(pool
            .where((p) => p.category == category && p.id != excludeId)
            .take(limit)
            .toList());
      }
      return Failure(AppError('Failed to load related products',
          cause: e, code: kFailureLoad));
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
  Future<Result<List<FlashSale>>> getActiveFlashSales() =>
      Result.guard(() async {
        final value = await _client.rpc('get_active_flash_sales');
        final rows = (value as List).whereType<Map<String, dynamic>>();
        return rows.map(FlashSaleCodec.fromRow).whereType<FlashSale>().toList();
      }, 'Failed to load flash sales');

  @override
  List<String> get defaultCategories => defaultCatalogCategories;

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
      // Best-effort cache write — never crash the app over persistence.
      // Logged without the raw error text; audit 2026-09-14 P0-5.
      Log.w('Catalog persistent cache write failed.', error: e);
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
          final product = ProductCodec.decode(entry as Map<Object?, Object?>);
          if (product != null) products.add(product);
        } catch (e) {
          // Per-entry fail-soft (logged without payload text; P0-5).
          Log.w('Catalog persistent cache skipping corrupt entry.', error: e);
        }
      }
      return products;
    } catch (e) {
      // Fail-soft restore (logged without payload text; P0-5).
      Log.w('Catalog persistent cache restore failed.', error: e);
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
