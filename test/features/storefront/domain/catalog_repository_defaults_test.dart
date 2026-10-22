import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// `implements` — not `extends` — because `CatalogRepository` is an
/// `abstract interface class`: the default bodies cannot be inherited
/// outside the defining library, so this double exists only to exercise
/// the static extension surface.
class _FakeCatalog implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Success(<Product>[]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(<String>[]);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('unused'));

  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async =>
      const Success(<Product>[]);

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success(<FlashSale>[]);

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const [];
}

void main() {
  test('lastPageTruncated defaults to false through the extension', () {
    final CatalogRepository catalog = _FakeCatalog();

    expect(catalog.lastPageTruncated, isFalse);
  });

  test('defaultCatalogCategories is the shared domain constant', () {
    expect(
      defaultCatalogCategories,
      ['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'],
    );
  });
}
