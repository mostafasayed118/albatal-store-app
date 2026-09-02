import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub catalog for cubit tests that don't need real product data.
class _StubCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);
  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);
  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Failure(AppError('Product not found'));
  @override
  Product? findProductById(String id) => null;
  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];

  @override
  List<String> get defaultCategories => const ['All'];
}

class _RepositoryFailureCatalog implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Failure(AppError('database unavailable'));
  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);
  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Failure(AppError('database unavailable'));
  @override
  Product? findProductById(String id) => null;
  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];

  @override
  List<String> get defaultCategories => const ['All'];
}

class _RelatedFetchThrowsCatalog implements CatalogRepository {
  static const requestedProduct = Product(
    id: 'requested',
    name: 'Requested',
    category: 'Silk',
    price: Money.egp(100),
    imageColor: 0xFF000000,
  );

  var _fetchProductsCalls = 0;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    _fetchProductsCalls++;
    if (_fetchProductsCalls == 2) {
      throw StateError('related products unavailable');
    }
    return const Success([requestedProduct]);
  }

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    final result = await fetchProducts();
    return result.when(
      success: (products) => Success(products.single),
      failure: Failure.new,
    );
  }

  @override
  Product? findProductById(String id) => requestedProduct;

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];

  @override
  List<String> get defaultCategories => const ['All'];
}

class _RelatedFetchFailureCatalog implements CatalogRepository {
  static const requestedProduct = _RelatedFetchThrowsCatalog.requestedProduct;

  var _fetchProductsCalls = 0;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    _fetchProductsCalls++;
    if (_fetchProductsCalls == 2) {
      return Failure(AppError('related products unavailable'));
    }
    return const Success([requestedProduct]);
  }

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    final result = await fetchProducts();
    return result.when(
      success: (products) => Success(products.single),
      failure: Failure.new,
    );
  }

  @override
  Product? findProductById(String id) => requestedProduct;

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];

  @override
  List<String> get defaultCategories => const ['All'];
}

void main() {
  group('Product', () {
    test('stockFor returns stock for a specific variant', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: Money.egp(100),
        imageColor: 0xFF000000,
        stock: {
          'Emerald-1m': 10,
          'Emerald-2m': 5,
          'Gold-1m': 0,
        },
      );
      expect(p.stockFor('Emerald', '1m'), 10);
      expect(p.stockFor('Emerald', '2m'), 5);
      expect(p.stockFor('Gold', '1m'), 0);
      expect(p.stockFor('Ivory', '5m'), 0);
    });

    test('inStock returns true when any variant has stock', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: Money.egp(100),
        imageColor: 0xFF000000,
        stock: {'A-1m': 0, 'B-1m': 5},
      );
      expect(p.inStock, isTrue);
    });

    test('inStock returns false when all variants are out of stock', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: Money.egp(100),
        imageColor: 0xFF000000,
        stock: {'A-1m': 0, 'B-1m': 0},
      );
      expect(p.inStock, isFalse);
    });

    test('discountPercent calculates correctly', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: Money.egp(850),
        imageColor: 0xFF000000,
        oldPrice: Money.egp(1000),
      );
      expect(p.discountPercent, 15);
    });

    test('discountPercent is null when no oldPrice', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: Money.egp(100),
        imageColor: 0xFF000000,
      );
      expect(p.discountPercent, isNull);
    });
  });

  group('CartItem', () {
    test('key combines product id, color, and length', () {
      const p = Product(
        id: 'silk-01',
        name: 'Silk',
        category: 'Silk',
        price: Money.egp(100),
        imageColor: 0xFF000000,
      );
      const item = CartItem(product: p, color: 'Emerald', length: '2m');
      expect(item.key, 'silk-01-Emerald-2m');
    });

    test('copyWith preserves all fields', () {
      const p = Product(
        id: 'silk-01',
        name: 'Silk',
        category: 'Silk',
        price: Money.egp(100),
        imageColor: 0xFF000000,
      );
      const item =
          CartItem(product: p, color: 'Gold', length: '5m', quantity: 3);
      final copy = item.copyWith(quantity: 5);
      expect(copy.product, p);
      expect(copy.color, 'Gold');
      expect(copy.length, '5m');
      expect(copy.quantity, 5);
    });
  });

  group('ProductDetailsCubit', () {
    blocTest<ProductDetailsCubit, DetailsState>(
      'emits loading and notFound when the requested id is absent',
      build: () => ProductDetailsCubit(_StubCatalogRepository()),
      act: (cubit) => cubit.loadProduct('missing'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading),
        const DetailsState(status: DetailsStatus.notFound),
      ],
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'emits loading and error with a safe message when the repository fails',
      build: () => ProductDetailsCubit(_RepositoryFailureCatalog()),
      act: (cubit) => cubit.loadProduct('product'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading),
        const DetailsState(
          status: DetailsStatus.error,
          errorMessage: 'Unable to load product details.',
        ),
      ],
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'preserves the primary product when related products throw',
      build: () => ProductDetailsCubit(_RelatedFetchThrowsCatalog()),
      act: (cubit) => cubit.loadProduct('requested'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading),
        DetailsState(
          status: DetailsStatus.ready,
          product: _RelatedFetchThrowsCatalog.requestedProduct,
          color: _RelatedFetchThrowsCatalog.requestedProduct.colors.first,
          length: _RelatedFetchThrowsCatalog.requestedProduct.sizes.first,
        ),
      ],
      verify: (cubit) {
        expect(
            cubit.state.product, _RelatedFetchThrowsCatalog.requestedProduct);
        expect(cubit.state.relatedProducts, isEmpty);
      },
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'preserves the primary product when related products return a failure',
      build: () => ProductDetailsCubit(_RelatedFetchFailureCatalog()),
      act: (cubit) => cubit.loadProduct('requested'),
      expect: () => [
        const DetailsState(status: DetailsStatus.loading),
        DetailsState(
          status: DetailsStatus.ready,
          product: _RelatedFetchFailureCatalog.requestedProduct,
          color: _RelatedFetchFailureCatalog.requestedProduct.colors.first,
          length: _RelatedFetchFailureCatalog.requestedProduct.sizes.first,
        ),
      ],
      verify: (cubit) {
        expect(
          cubit.state.product,
          _RelatedFetchFailureCatalog.requestedProduct,
        );
        expect(cubit.state.relatedProducts, isEmpty);
      },
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'changes color',
      build: () => ProductDetailsCubit(_StubCatalogRepository()),
      act: (cubit) => cubit.color('Gold'),
      verify: (cubit) => expect(cubit.state.color, 'Gold'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'changes length',
      build: () => ProductDetailsCubit(_StubCatalogRepository()),
      act: (cubit) => cubit.length('5m'),
      verify: (cubit) => expect(cubit.state.length, '5m'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'changes quantity with clamping',
      build: () => ProductDetailsCubit(_StubCatalogRepository()),
      act: (cubit) {
        cubit.quantity(0);
        cubit.quantity(100);
        cubit.quantity(5);
      },
      verify: (cubit) => expect(cubit.state.quantity, 5),
    );
  });
}
