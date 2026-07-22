import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubCatalogRepository implements CatalogRepository {
  _StubCatalogRepository({this.products, this.shouldFail = false});

  final List<Product>? products;
  final bool shouldFail;

  @override
  Future<Result<List<Product>>> fetchProducts() async {
    if (shouldFail) {
      return const Failure(AppError('Failed to load products'));
    }
    return Success(products ?? []);
  }

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Product? findProductById(String id) =>
      products?.where((p) => p.id == id).firstOrNull;

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
        stock: {'Emerald-1m': 10, 'Emerald-2m': 5, 'Gold-1m': 0},
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

  group('ProductDetailsCubit — loading / success / error / retry', () {
    blocTest<ProductDetailsCubit, DetailsState>(
      'emits loading then ready on success',
      build: () => ProductDetailsCubit(
        _StubCatalogRepository(products: products),
      ),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.loading),
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.ready),
      ],
      verify: (cubit) {
        expect(cubit.state.product?.id, 'silk-01');
        expect(cubit.state.product?.name, 'Royal Emerald Silk');
        expect(cubit.state.relatedProducts, isNotEmpty);
      },
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'emits loading then error on failure',
      build: () => ProductDetailsCubit(
        _StubCatalogRepository(shouldFail: true),
      ),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.loading),
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.error),
      ],
      verify: (cubit) {
        expect(cubit.state.product, isNull);
        expect(cubit.state.errorMessage, isNotNull);
      },
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'emits error on empty catalog',
      build: () => ProductDetailsCubit(
        _StubCatalogRepository(products: []),
      ),
      act: (cubit) => cubit.loadProduct('silk-01'),
      expect: () => [
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.loading),
        isA<DetailsState>()
            .having((s) => s.status, 'status', DetailsStatus.error),
      ],
    );

    test('retry is no-op when no product was previously loaded', () async {
      final cubit = ProductDetailsCubit(
        _StubCatalogRepository(products: products),
      );
      cubit.retry();
      expect(cubit.state.status, DetailsStatus.loading);
      await cubit.close();
    });

    blocTest<ProductDetailsCubit, DetailsState>(
      'retry transitions from error to loading to ready',
      build: () => ProductDetailsCubit(
        _StubCatalogRepository(products: products),
      ),
      act: (cubit) {
        cubit.loadProduct('silk-01');
      },
      expect: () => [
        isA<DetailsState>()
            .having((s) => s.status, '1: loading', DetailsStatus.loading),
        isA<DetailsState>()
            .having((s) => s.status, '2: ready', DetailsStatus.ready),
      ],
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
