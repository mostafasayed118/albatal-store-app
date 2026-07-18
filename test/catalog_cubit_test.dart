import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/storefront_cubits.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub repository that returns the fixed product list — no network, no I/O.
final class StubCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));
}

/// Stub repository that always fails.
final class FailingCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Failure(AppError('Catalog unavailable'));
}

void main() {
  group('CatalogCubit — happy path', () {
    blocTest<CatalogCubit, CatalogState>(
      'loads products via repository and transitions to ready',
      build: () => CatalogCubit(StubCatalogRepository()),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        isA<CatalogState>()
            .having((s) => s.status, 'status', CatalogStatus.ready)
            .having((s) => s.allProducts.length, 'products', 5)
            .having((s) => s.categories.length, 'categories', 6),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'filters catalog results by a case-insensitive product query',
      build: () => CatalogCubit(StubCatalogRepository()),
      wait: const Duration(milliseconds: 400),
      seed: () => const CatalogState(
          status: CatalogStatus.ready,
          allProducts: products,
          categories: categories),
      act: (cubit) => cubit.updateQuery('VELVET'),
      expect: () => [isA<CatalogState>().having((s) => s.query, 'query', 'VELVET')],
      verify: (cubit) {
        expect(cubit.state.visible, hasLength(1));
        expect(cubit.state.visible.single.name, 'Midnight Velvet');
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'orders the full catalog by descending price',
      build: () => CatalogCubit(StubCatalogRepository()),
      wait: const Duration(milliseconds: 400),
      seed: () => const CatalogState(
          status: CatalogStatus.ready,
          allProducts: products,
          categories: categories),
      act: (cubit) => cubit.selectSort(CatalogSort.priceHighToLow),
      verify: (cubit) => expect(
        cubit.state.visible.map((product) => product.price),
        [1290, 980, 820, 690, 540],
      ),
    );

    blocTest<CatalogCubit, CatalogState>(
      'clears query, category, and sorting together',
      build: () => CatalogCubit(StubCatalogRepository()),
      wait: const Duration(milliseconds: 400),
      seed: () => const CatalogState(
          status: CatalogStatus.ready,
          allProducts: products,
          categories: categories),
      act: (cubit) {
        cubit.updateQuery('silk');
        cubit.select('Silk');
        cubit.selectSort(CatalogSort.name);
        cubit.clearFilters();
      },
      expect: () => [
        isA<CatalogState>(),
        isA<CatalogState>(),
        isA<CatalogState>(),
        isA<CatalogState>()
            .having((s) => s.category, 'category', 'All')
            .having((s) => s.query, 'query', '')
            .having((s) => s.sort, 'sort', CatalogSort.featured),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'records recent queries after debounce settles',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: () => const CatalogState(
          status: CatalogStatus.ready,
          allProducts: products,
          categories: categories),
      act: (cubit) {
        cubit.updateQuery('silk');
        cubit.updateQuery('velvet');
      },
      wait: const Duration(milliseconds: 500),
      verify: (cubit) {
        expect(cubit.state.recentQueries, contains('silk'));
        expect(cubit.state.recentQueries, contains('velvet'));
      },
    );
  });

  group('CatalogCubit — error path', () {
    blocTest<CatalogCubit, CatalogState>(
      'transitions to error when the repository fails',
      build: () => CatalogCubit(FailingCatalogRepository()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.error),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'can retry a failed load',
      build: () => CatalogCubit(FailingCatalogRepository()),
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.error),
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.error),
      ],
    );
  });
}
