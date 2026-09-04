import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';

import 'products_data.dart';

/// Local in-memory catalog repository backed by the fixed [products] constant.
///
/// Test double only — located under `test/` for the same reason as
/// [products]: a previous home in `lib/features/storefront/data/` caused
/// it to be compiled into release builds even though no production code
/// referenced it. It always succeeds; the Cubit still talks through
/// `Result<List<Product>>` so a remote implementation can be swapped in
/// without touching the Cubit or UI.
final class LocalCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    final product = products.where((p) => p.id == id).firstOrNull;
    if (product != null) return Success(product);
    return Failure(AppError('Product not found'));
  }

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => categories;
}
