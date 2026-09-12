import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';

/// Test-only [CatalogRepository.fetchRelated] default.
///
/// `interface class` members are never inherited, so every fake must name a
/// `fetchRelated` implementation even though the interface carries a default
/// body. Mixing this in (instead of hand-rolling per fake) keeps the suite's
/// related-path semantics in one place: filter the [fetchProducts] list by
/// category, drop [excludeId], cap at [limit].
mixin FetchRelatedFromProducts {
  Future<Result<List<Product>>> fetchProducts();

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
}
