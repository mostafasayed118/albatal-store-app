import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
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

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => categories;
}

/// Stub repository that always fails.
final class FailingCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Failure(AppError('Catalog unavailable'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];
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
            .having((s) => s.allProducts.length, 'products', 9)
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
        expect(cubit.state.visible, hasLength(2));
        expect(cubit.state.visible.every((p) => p.name.contains('Velvet')),
            isTrue);
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'orders the full catalog by descending price',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) => cubit.selectSort(CatalogSort.priceHighToLow),
      verify: (cubit) => expect(
        cubit.state.visible.map((product) => product.price.minorUnits),
        [
          Money.egp(1340).minorUnits,
          Money.egp(1290).minorUnits,
          Money.egp(1050).minorUnits,
          Money.egp(980).minorUnits,
          Money.egp(820).minorUnits,
          Money.egp(720).minorUnits,
          Money.egp(690).minorUnits,
          Money.egp(580).minorUnits,
          Money.egp(540).minorUnits,
        ],
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

  group('CatalogCubit — color filter', () {
    blocTest<CatalogCubit, CatalogState>(
      'filters products by color',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) => cubit.setColorFilter('Emerald'),
      verify: (cubit) {
        expect(cubit.state.colorFilter, 'Emerald');
        expect(cubit.state.visible, hasLength(1));
        expect(cubit.state.visible.first.name, 'Royal Emerald Silk');
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'toggles color filter off when same color selected again',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) {
        cubit.setColorFilter('Emerald');
        cubit.setColorFilter('Emerald');
      },
      verify: (cubit) {
        expect(cubit.state.colorFilter, isEmpty);
        expect(cubit.state.visible.length, 9);
      },
    );
  });

  group('CatalogCubit — price range filter', () {
    blocTest<CatalogCubit, CatalogState>(
      'filters products by price range',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) =>
          cubit.setPriceRange(const Money.egp(500), const Money.egp(800)),
      verify: (cubit) {
        expect(cubit.state.priceMin, const Money.egp(500));
        expect(cubit.state.priceMax, const Money.egp(800));
        for (final p in cubit.state.visible) {
          expect(
              p.price.minorUnits,
              inInclusiveRange(
                  Money.egp(500).minorUnits, Money.egp(800).minorUnits));
        }
      },
    );
  });

  group('CatalogCubit — newest sort', () {
    blocTest<CatalogCubit, CatalogState>(
      'sorts products by newest (id descending)',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) => cubit.selectSort(CatalogSort.newest),
      verify: (cubit) {
        expect(cubit.state.sort, CatalogSort.newest);
        final ids = cubit.state.visible.map((p) => p.id).toList();
        for (var i = 0; i < ids.length - 1; i++) {
          expect(ids[i].compareTo(ids[i + 1]), greaterThanOrEqualTo(0));
        }
      },
    );
  });

  group('CatalogCubit — combined filters', () {
    blocTest<CatalogCubit, CatalogState>(
      'clears query, category, and sorting together',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) {
        cubit.select('Silk');
        cubit.setPriceRange(const Money.egp(1200), const Money.egp(1400));
      },
      verify: (cubit) {
        // Both silk products are in this price range
        expect(cubit.state.visible.length, 2);
        expect(cubit.state.visible.every((p) => p.category == 'Silk'), isTrue);
      },
    );

    blocTest<CatalogCubit, CatalogState>(
      'clearFilters resets all filters',
      build: () => CatalogCubit(StubCatalogRepository()),
      seed: seededState,
      act: (cubit) {
        cubit.select('Silk');
        cubit.setColorFilter('Emerald');
        cubit.setPriceRange(const Money.egp(500), const Money.egp(1000));
        cubit.updateQuery('silk');
        cubit.clearFilters();
      },
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        expect(cubit.state.category, 'All');
        expect(cubit.state.colorFilter, isEmpty);
        expect(cubit.state.priceMin, Money.zero);
        expect(cubit.state.priceMax, const Money.egp(999999));
        expect(cubit.state.query, isEmpty);
        expect(cubit.state.sort, CatalogSort.featured);
        expect(cubit.state.visible.length, 9);
      },
    );
  });

  group('CatalogCubit — availableColors', () {
    test('returns unique color names from products', () async {
      final cubit = CatalogCubit(StubCatalogRepository());
      expect(cubit.state.availableColors, isEmpty);
      await cubit.load();
      expect(cubit.state.availableColors, contains('Emerald'));
      expect(cubit.state.availableColors, contains('Gold'));
      expect(cubit.state.availableColors.length, 9);
      cubit.close();
    });
  });
}
