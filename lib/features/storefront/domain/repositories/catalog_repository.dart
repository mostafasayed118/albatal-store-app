import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../entities/flash_sale.dart';

/// Abstract data source for the product catalog.
///
/// The storefront currently runs on a fixed in-memory product list, so this
/// repository is intentionally thin. The abstraction earns its keep the moment
/// the catalog becomes remote, paginated, cached, or backed by a database:
/// the Cubit stays the same and only the implementation swaps.
///
/// Fallback category names used when the server provides none (first-frame
/// render before the cubit loads).
///
/// Domain-owned single source of truth (audit 2026-09-14 V1): the data
/// layer (`SupabaseCatalogRepository.defaultCategories`) reads this const
/// instead of importing `presentation/catalog_constants.dart`, so the
/// dependency rule `presentation → domain → data` holds. Presentation
/// keeps its richer `CatalogConstants` (accents, swatches, chips) and
/// delegates its fallback list here.
const defaultCatalogCategories = <String>[
  'Silk',
  'Cotton',
  'Velvet',
  'Linen',
  'Wool',
];

abstract interface class CatalogRepository {
  Future<Result<List<Product>>> fetchProducts();
  Future<Result<List<String>>> fetchCategories();

  /// Fetch a single product by [id] — single-row query, not N-product fan-out.
  ///
  /// Implementations should check the in-memory cache first
  /// (`_cache?.firstWhere`) then fall back to a
  /// `select(...).eq('id', id).single()` query, handling the Postgrest
  /// single() throw when not found.
  Future<Result<Product>> fetchProductById(String id);

  /// Category-scoped related-products query.
  ///
  /// Default implementation derives from [fetchProducts] so existing
  /// fakes/stubs remain valid without override. Remote implementations
  /// (Supabase) override with a bounded category-filtered query instead
  /// of pulling the full catalog for a related strip.
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) =>
      fetchProducts().then(
        (result) => result.when(
          success: (all) => Success(all
              .where((p) => p.category == category && p.id != excludeId)
              .take(limit)
              .toList()),
          failure: Failure.new,
        ),
      );

  /// Synchronous lookup used by hydration paths (cart restore, wishlist
  /// resolve) that need a [Product] from its id without awaiting a fetch.
  /// Returns `null` when the id is not in the catalog.
  Product? findProductById(String id);

  /// Synchronous access to the category list used as a fallback when
  /// the cubit hasn't loaded yet (e.g. first-frame render).
  List<String> get defaultCategories;

  /// Active flash sales from `flash_sales` table.
  ///
  /// Default implementation returns an empty success so existing fakes/stubs
  /// remain valid without override. Remote implementations (Supabase)
  /// override to call `rpc('get_active_flash_sales')` and map rows via
  /// `FlashSaleCodec.fromRow`, failing closed on transport errors.
  Future<Result<List<FlashSale>>> getActiveFlashSales() =>
      Future.value(const Success<List<FlashSale>>([]));
}

/// Truncation flag for the bounded catalog page (audit Top-5 #3).
///
/// Implemented as an extension with a `false` default — not an interface
/// member — so existing fakes stay valid without modification. The
/// Supabase implementation declares its own measured
/// [SupabaseCatalogRepository.lastPageTruncated] field (instance members
/// win over extension members), and fakes that need to simulate a full
/// page can declare the same getter.
extension CatalogTruncation on CatalogRepository {
  bool get lastPageTruncated => false;
}
