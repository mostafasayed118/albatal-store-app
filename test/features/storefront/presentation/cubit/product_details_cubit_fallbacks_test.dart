import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wholesale_price_source.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';

final class _LegacyCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('single fetch down'));

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

final class _ThrowingCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      throw StateError('catalog exploded');

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      throw StateError('single fetch exploded');

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

final class _ThrowingPrices implements WholesalePriceSource {
  @override
  Future<Map<String, Money>> fetchWholesalePrices(
          Iterable<String> productIds) async =>
      throw StateError('price list exploded');
}

void main() {
  test('legacy full-catalog fallback resolves the product and its related',
      () async {
    final cubit = ProductDetailsCubit(_LegacyCatalog());
    addTearDown(cubit.close);

    await cubit.loadProduct('silk-01');

    expect(cubit.state.status, DetailsStatus.ready);
    expect(cubit.state.product?.id, 'silk-01');
    expect(cubit.state.relatedProducts.map((p) => p.id), ['silk-02']);
    expect(cubit.state.color, 'Emerald');
    expect(cubit.state.length, '1m');
  });

  test('an unexpected throw during load degrades to the error state', () async {
    final cubit = ProductDetailsCubit(_ThrowingCatalog());
    addTearDown(cubit.close);

    await cubit.loadProduct('silk-01');

    expect(cubit.state.status, DetailsStatus.error);
    expect(cubit.state.product, isNull);
  });

  test('a failing wholesale price fetch keeps the catalog price', () async {
    final cubit = ProductDetailsCubit(
      _LegacyCatalog(),
      wholesalePrices: _ThrowingPrices(),
    );
    addTearDown(cubit.close);

    await cubit.loadProduct(
      'silk-01',
      viewerTier: MembershipTier.wholesale,
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, DetailsStatus.ready);
    expect(cubit.state.product?.wholesalePrice, isNull);
  });
}
