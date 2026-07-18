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

/// Pre-seeded state with products loaded — avoids testing load() in every test.
CatalogState seededState([CatalogSort sort = CatalogSort.featured]) =>
    CatalogState(
      status: CatalogStatus.ready,
      allProducts: products,
      categories: categories,
      sort: sort,
    );

void main() {
  group('CatalogCubit — load', () {
    blocTest<CatalogCubit, CatalogState>(
      'loads products via repository and transitions loading → ready',
      build: () => CatalogCubit(StubCatalogRepository()),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        isA<CatalogState>()
            .having((s) => s.status, 'status', CatalogStatus.ready)
            .having((s) => s.allProducts.length, 'products', 5)
            .having((s) => s.categories.length, 'categories', 6),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'transitions to error when the repository fails',
      build: () => CatalogCubit(FailingCatalogRepository()),
      act: (cubit) => cubit.load(),
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

  group('CatalogCubit — filtering', () {
    blocTest<CatalogCubit, CatalogState>(
      'filters catalog results by a case-insensitive product query',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) => cubit.updateQuery('VELVET'),
      wait: const Duration(milliseconds: 400),
      verify: (cubit) {
        expect(cubit.state.query, 'VELVET');
        expect(cubit.state.visible, hasLength(1));
        expect(cubit.state.visible.single.name, 'Midnight Velvet');
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'orders the full catalog by descending price',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) => cubit.selectSort(CatalogSort.priceHighToLow),
      verify: (cubit) => expect(
        cubit.state.visible.map((product) => product.price),
        [1290, 980, 820, 690, 540],
      ),
    );

    blocTest<CatalogCubit, CatalogState>(
      'clears query, category, and sorting together',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) {
        cubit.updateQuery('silk');
        cubit.select('Silk');
        cubit.selectSort(CatalogSort.name);
        cubit.clearFilters();
      },
      wait: const Duration(milliseconds: 400),
      verify: (cubit) {
        expect(cubit.state.category, 'All');
        expect(cubit.state.query, '');
        expect(cubit.state.sort, CatalogSort.featured);
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'records recent queries after debounce settles',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) {
        cubit.updateQuery('silk');
        cubit.updateQuery('velvet');
      },
      wait: const Duration(milliseconds: 500),
      verify: (cubit) {
        // Only 'velvet' is recorded — the debounce cancels the earlier 'silk' timer.
        expect(cubit.state.recentQueries, ['velvet']);
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'debounces rapid queries — only the last triggers a recent record',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) {
        cubit.updateQuery('s');
        cubit.updateQuery('si');
        cubit.updateQuery('silk');
      },
      wait: const Duration(milliseconds: 500),
      verify: (cubit) {
        expect(cubit.state.recentQueries, ['silk']);
      },
    );
  });
}
