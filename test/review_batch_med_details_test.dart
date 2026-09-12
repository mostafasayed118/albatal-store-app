import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/local_catalog_repository.dart';
import 'helpers/fetch_related_stub.dart';

const _product = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
  colors: ['Emerald', 'Gold'],
  sizes: ['1m', '2m'],
  stock: {'Emerald-1m': 10, 'Gold-2m': 4},
);

const _readyWithProduct = DetailsState(
  status: DetailsStatus.ready,
  product: _product,
  color: 'Emerald',
  length: '1m',
  quantity: 1,
);

/// Records which related-path the cubit takes.
class _RecordingCatalog implements CatalogRepository {
  var fetchProductsCalls = 0;
  var fetchRelatedCalls = 0;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    fetchProductsCalls++;
    return const Success([_product]);
  }

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Success(_product);

  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async {
    fetchRelatedCalls++;
    return const Success([]);
  }

  @override
  Product? findProductById(String id) => _product;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

const _productA = Product(
  id: 'a',
  name: 'Alpha Silk',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
);

const _productB = Product(
  id: 'b',
  name: 'Beta Cotton',
  category: 'Cotton',
  price: Money.egp(200),
  imageColor: 0xFF111111,
);

/// Slow-A / fast-B related fetches to prove the generation guard.
class _RacingCatalog implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Success([_productA, _productB]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Success(id == 'a' ? _productA : _productB);

  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async {
    if (excludeId == 'a') {
      await Future.delayed(const Duration(milliseconds: 100));
      return const Success([_productB]);
    }
    return const Success([_productA]);
  }

  @override
  Product? findProductById(String id) => id == 'a' ? _productA : _productB;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

class _FailingCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Failure(AppError('offline'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('offline'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

void main() {
  group('ProductDetailsCubit — fetchRelated path (review-batch-med)', () {
    test('loads related via fetchRelated, never the full catalog', () async {
      final repo = _RecordingCatalog();
      final cubit = ProductDetailsCubit(repo);
      await cubit.loadProduct('silk-01');
      expect(repo.fetchRelatedCalls, 1);
      expect(repo.fetchProductsCalls, 0,
          reason: 'the related strip must not pull the full catalog');
      expect(cubit.state.status, DetailsStatus.ready);
      await cubit.close();
    });
  });

  group('ProductDetailsCubit — variant validation (review-batch-med)', () {
    blocTest<ProductDetailsCubit, DetailsState>(
      'rejects colors outside the loaded product',
      build: () => ProductDetailsCubit(_RecordingCatalog()),
      seed: () => _readyWithProduct,
      act: (cubit) => cubit.color('Magenta'),
      verify: (cubit) => expect(cubit.state.color, 'Emerald'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'accepts colors inside the loaded product',
      build: () => ProductDetailsCubit(_RecordingCatalog()),
      seed: () => _readyWithProduct,
      act: (cubit) => cubit.color('Gold'),
      verify: (cubit) => expect(cubit.state.color, 'Gold'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'rejects lengths outside the loaded product',
      build: () => ProductDetailsCubit(_RecordingCatalog()),
      seed: () => _readyWithProduct,
      act: (cubit) => cubit.length('9m'),
      verify: (cubit) => expect(cubit.state.length, '1m'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'pins quantity to 1 for out-of-stock variants',
      build: () => ProductDetailsCubit(_RecordingCatalog()),
      // Gold-1m has no stock entry → stockFor is 0.
      seed: () => _readyWithProduct.copyWith(color: 'Gold'),
      act: (cubit) => cubit.quantity(5),
      verify: (cubit) => expect(cubit.state.quantity, 1),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'clamps quantity to the in-stock variant ceiling',
      build: () => ProductDetailsCubit(_RecordingCatalog()),
      seed: () => _readyWithProduct,
      act: (cubit) => cubit.quantity(99),
      verify: (cubit) => expect(cubit.state.quantity, 10),
    );
  });

  group('ProductDetailsCubit — generation guard (review-batch-med)', () {
    test('a slow A load cannot clobber a newer B state', () async {
      final cubit = ProductDetailsCubit(_RacingCatalog());
      await Future.wait([
        cubit.loadProduct('a'),
        cubit.loadProduct('b'),
      ]);
      expect(cubit.state.product?.id, 'b');
      expect(
        cubit.state.relatedProducts.map((p) => p.id),
        ['a'],
        reason: 'related must belong to B, not the stale A fetch',
      );
      await cubit.close();
    });
  });

  group('CatalogRepository.fetchRelated default (review-batch-med)', () {
    test('filters by category, drops excludeId, caps at limit', () async {
      final repo = LocalCatalogRepository();
      final related =
          await repo.fetchRelated('Silk', excludeId: 'silk-01', limit: 1);
      related.when(
        success: (items) {
          expect(items, hasLength(1));
          expect(items.first.id, 'silk-02');
        },
        failure: (_) => fail('expected success'),
      );
    });

    test('propagates repository failure', () async {
      final related = await _FailingCatalog().fetchRelated('Silk');
      expect(related, isA<Failure<List<Product>>>());
    });
  });
}
