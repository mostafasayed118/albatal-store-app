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
/// This replaces [LocalCatalogRepository] (slug-based mock data) for
/// any environment where the Supabase `products` / `product_variants`
/// tables are seeded.
final class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// In-memory cache of the full product list so that [findProductById]
  /// is synchronous (required by the hydration path that restores the
  /// cart from SharedPreferences without awaiting a network call).
  List<Product>? _cache;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    try {
      // ── 1. Fetch active products with their category name ──────
      final productRows = await _client
          .from('products')
          .select('id, name, slug, description, composition, care, origin, '
              'base_price, old_price, rating, review_count, '
              'categories!inner(name)')
          .eq('is_active', true)
          .order('name');

      // ── 2. Fetch all active variants in one query ──────────────
      final variantRows = await _client
          .from('product_variants')
          .select('product_id, size, color, stock, price_override')
          .eq('is_active', true);

      // ── 3. Group variants by product_id ────────────────────────
      final variantsByProduct = <String, List<Map<String, dynamic>>>{};
      for (final v in variantRows) {
        final pid = v['product_id'] as String;
        variantsByProduct.putIfAbsent(pid, () => []).add(v);
      }

      // ── 4. Map rows to Product entities ────────────────────────
      final result = <Product>[];
      for (final row in productRows) {
        final pid = row['id'] as String;
        final variants = variantsByProduct[pid] ?? [];

        result.add(_mapProduct(row, variants));
      }

      _cache = result;
      return Success(result);
    } on Exception catch (e) {
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
