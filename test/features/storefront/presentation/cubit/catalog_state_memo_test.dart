import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a catalog of [count] products with deterministic ids/prices.
List<Product> makeProducts(int count) => List.generate(
      count,
      (i) => Product(
        id: 'p-$i',
        name: 'Product $i',
        category: i.isEven ? 'Silk' : 'Wool',
        price: Money((i + 1) * 1000),
        imageColor: 0xFF176B57,
      ),
    );

void main() {
  group('CatalogState — memoized derived views (audit finding #5)', () {
    test('derived getters return identical instances across repeat calls', () {
      final state = CatalogState(allProducts: makeProducts(50));

      // First call computes, second call must return the SAME object —
      // proving the memo actually short-circuits recomputation.
      expect(identical(state.visible, state.visible), isTrue);
      expect(identical(state.availableColors, state.availableColors), isTrue);
      expect(identical(state.categoryProductCount, state.categoryProductCount),
          isTrue);
      expect(identical(state.catalogPriceMin, state.catalogPriceMin), isTrue);
      expect(identical(state.catalogPriceMax, state.catalogPriceMax), isTrue);
      expect(
          identical(state.productsInCategory('Silk'),
              state.productsInCategory('Silk')),
          isTrue);
    });

    test('visible list is correct and memo survives repeated reads', () {
      final products = makeProducts(50);
      final state = CatalogState(
        allProducts: products,
        filters: const CatalogFilters(category: 'Silk'),
      );

      final first = state.visible;
      expect(first.length, 25); // evens only
      expect(first.every((p) => p.category == 'Silk'), isTrue);
      expect(identical(first, state.visible), isTrue);
    });

    test('visible recomputes when filters change, memoizes per filter value',
        () {
      final products = makeProducts(50);
      final state = CatalogState(allProducts: products);

      final all = state.visible;
      expect(all.length, 50);

      // Change filters — must NOT reuse the previous memo.
      final silkState = state.copyWith(
        filters: const CatalogFilters(category: 'Silk'),
      );
      final silk = silkState.visible;
      expect(silk.length, 25);

      // An equal state (same filters) built fresh must produce an equal
      // (but distinct) list — and repeat reads on it reuse its own memo.
      final silkState2 = CatalogState(
        allProducts: products,
        filters: const CatalogFilters(category: 'Silk'),
      );
      expect(silkState2.visible, equals(silk));
      expect(identical(silkState2.visible, silkState2.visible), isTrue);

      // Sorted variant: price low→high applied on top of the filter.
      final sortedState = silkState.copyWith(
        filters: const CatalogFilters(
          category: 'Silk',
          sort: CatalogSort.priceLowToHigh,
        ),
      );
      final sorted = sortedState.visible;
      expect(sorted.first.price, const Money(1000));
      expect(sorted.last.price, const Money(49000));
    });

    test('productsInCategory memoizes per category key', () {
      final state = CatalogState(allProducts: makeProducts(20));

      final silk = state.productsInCategory('Silk');
      expect(silk.length, 10);
      expect(identical(silk, state.productsInCategory('Silk')), isTrue);

      final wool = state.productsInCategory('Wool');
      expect(wool.length, 10);
      expect(identical(wool, state.productsInCategory('Wool')), isTrue);
    });

    test('equality ignores memos: equal states are equal and hash equal', () {
      final products = makeProducts(10);
      final a = CatalogState(allProducts: products);
      final b = CatalogState(allProducts: products);

      // Touch a's memos, then compare with untouched b.
      a.visible;
      a.availableColors;

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('catalogPriceMin/Max memoize correct bounds', () {
      final state = CatalogState(allProducts: makeProducts(9));
      expect(state.catalogPriceMin, const Money(1000));
      expect(state.catalogPriceMax, const Money(9000));
    });
  });
}
