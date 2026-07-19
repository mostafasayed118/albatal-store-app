import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';

/// Abstract data source for the product catalog.
///
/// The storefront currently runs on a fixed in-memory product list, so this
/// repository is intentionally thin. The abstraction earns its keep the moment
/// the catalog becomes remote, paginated, cached, or backed by a database:
/// the Cubit stays the same and only the implementation swaps.
abstract interface class CatalogRepository {
  Future<Result<List<Product>>> fetchProducts();
  Future<Result<List<String>>> fetchCategories();

  /// Synchronous lookup used by hydration paths (cart restore, wishlist
  /// resolve) that need a [Product] from its id without awaiting a fetch.
  /// Returns `null` when the id is not in the catalog.
  Product? findProductById(String id);

  /// Synchronous access to the category list used as a fallback when
  /// the cubit hasn't loaded yet (e.g. first-frame render).
  List<String> get defaultCategories;
}
