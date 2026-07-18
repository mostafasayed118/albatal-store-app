import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../domain/repositories/catalog_repository.dart';
import 'products_data.dart';

/// Local in-memory catalog repository backed by the fixed [products] constant.
///
/// This is the real implementation behind `CatalogRepository` for the mock
/// storefront. It always succeeds, making it trivial — but the Cubit still
/// talks through `Result<List<Product>>` so swapping in a remote API later
/// means changing this file, not the Cubit or the UI.
final class LocalCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));
}
