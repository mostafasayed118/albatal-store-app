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
}

/// A pair of catalog data returned together to avoid two round-trips.
final class CatalogData {
  const CatalogData({required this.products, required this.categories});
  final List<Product> products;
  final List<String> categories;
}
