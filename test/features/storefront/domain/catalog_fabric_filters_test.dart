import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  required String id,
  int? gsm,
  int? widthCm,
  String? composition,
  Map<String, int> stock = const {'Emerald-1m': 5},
  bool sellByLength = false,
  double rating = 4.0,
}) =>
    Product(
      id: id,
      name: id,
      category: 'Cotton',
      price: const Money.egp(100),
      imageColor: 0,
      gsm: gsm,
      widthCm: widthCm,
      composition: composition,
      stock: stock,
      sellByLength: sellByLength,
      rating: rating,
    );

/// Attribute finder v1 (Batch 3 #4): facet matching over existing columns.
void main() {
  final light = _product(id: 'light', gsm: 120, widthCm: 140);
  final medium = _product(
      id: 'medium', gsm: 200, widthCm: 150, composition: 'Egyptian Cotton');
  final heavy = _product(id: 'heavy', gsm: 350, widthCm: 160);
  final unspecified = _product(id: 'na');
  final outOfStock = _product(id: 'oos', gsm: 200, stock: const {});
  final metered = _product(id: 'metered', gsm: 200, sellByLength: true);
  final lowRated = _product(id: 'low', gsm: 200, rating: 2.0);

  group('defaults are inert', () {
    test('const defaults match everything (no behavior change)', () {
      const filters = CatalogFilters();
      for (final p in [light, medium, heavy, unspecified, outOfStock]) {
        expect(filters.matches(p), isTrue, reason: p.id);
      }
      expect(filters.hasActiveFilters, isFalse);
    });
  });

  group('weight bands', () {
    test('light < 150, medium 150-300, heavy > 300', () {
      expect(const CatalogFilters(weight: FabricWeight.light).matches(light),
          isTrue);
      expect(const CatalogFilters(weight: FabricWeight.light).matches(medium),
          isFalse);
      expect(const CatalogFilters(weight: FabricWeight.medium).matches(medium),
          isTrue);
      expect(const CatalogFilters(weight: FabricWeight.heavy).matches(heavy),
          isTrue);
      expect(const CatalogFilters(weight: FabricWeight.heavy).matches(medium),
          isFalse);
    });

    test('band edges are inclusive on medium', () {
      expect(
          const CatalogFilters(weight: FabricWeight.medium)
              .matches(_product(id: 'e150', gsm: 150)),
          isTrue);
      expect(
          const CatalogFilters(weight: FabricWeight.medium)
              .matches(_product(id: 'e300', gsm: 300)),
          isTrue);
      expect(
          const CatalogFilters(weight: FabricWeight.light)
              .matches(_product(id: 'e150', gsm: 150)),
          isFalse);
      expect(
          const CatalogFilters(weight: FabricWeight.heavy)
              .matches(_product(id: 'e300', gsm: 300)),
          isFalse);
    });

    test('null gsm only matches unspecified (or any)', () {
      expect(
          const CatalogFilters(weight: FabricWeight.unspecified)
              .matches(unspecified),
          isTrue);
      expect(
          const CatalogFilters(weight: FabricWeight.light).matches(unspecified),
          isFalse);
      expect(
          const CatalogFilters(weight: FabricWeight.unspecified).matches(light),
          isFalse);
    });
  });

  group('width bands', () {
    test('narrow < 150, standard == 150, wide > 150', () {
      expect(const CatalogFilters(width: FabricWidth.narrow).matches(light),
          isTrue);
      expect(const CatalogFilters(width: FabricWidth.standard).matches(medium),
          isTrue);
      expect(
          const CatalogFilters(width: FabricWidth.wide).matches(heavy), isTrue);
      expect(const CatalogFilters(width: FabricWidth.wide).matches(medium),
          isFalse);
    });

    test('null width only matches unspecified', () {
      expect(
          const CatalogFilters(width: FabricWidth.unspecified)
              .matches(unspecified),
          isTrue);
      expect(
          const CatalogFilters(width: FabricWidth.narrow).matches(unspecified),
          isFalse);
    });
  });

  group('fabric keyword', () {
    test('curated keyword matches composition case-insensitively', () {
      expect(const CatalogFilters(fabricKeyword: 'COTTON').matches(medium),
          isTrue);
      expect(
          const CatalogFilters(fabricKeyword: 'silk').matches(medium), isFalse);
    });

    test('unknown keyword constrains nothing (fail-open)', () {
      expect(const CatalogFilters(fabricKeyword: 'unobtainium').matches(light),
          isTrue);
    });

    test('null composition matches only empty keyword', () {
      expect(const CatalogFilters(fabricKeyword: 'cotton').matches(light),
          isFalse);
    });
  });

  group('stock / cut / rating', () {
    test('inStockOnly hides zero-stock rows', () {
      expect(
          const CatalogFilters(inStockOnly: true).matches(outOfStock), isFalse);
      expect(const CatalogFilters(inStockOnly: true).matches(light), isTrue);
    });

    test('sellByLengthOnly keeps metered rows', () {
      expect(const CatalogFilters(sellByLengthOnly: true).matches(metered),
          isTrue);
      expect(
          const CatalogFilters(sellByLengthOnly: true).matches(light), isFalse);
    });

    test('minRating is inclusive', () {
      expect(const CatalogFilters(minRating: 4.0).matches(medium), isTrue);
      expect(const CatalogFilters(minRating: 4.1).matches(medium), isFalse);
      expect(const CatalogFilters(minRating: 3.0).matches(lowRated), isFalse);
    });
  });

  group('combos + reset', () {
    test('facets compose with existing category/price filters', () {
      const filters = CatalogFilters(
        weight: FabricWeight.medium,
        fabricKeyword: 'cotton',
        inStockOnly: true,
      );
      expect(filters.matches(medium), isTrue);
      expect(filters.matches(light), isFalse); // weight + keyword
      expect(filters.matches(outOfStock), isFalse); // stock
      expect(filters.hasActiveFilters, isTrue);
    });

    test('clearFabricFilters resets only the finder facets', () {
      const filters = CatalogFilters(
        query: 'cot',
        weight: FabricWeight.heavy,
        width: FabricWidth.wide,
        fabricKeyword: 'silk',
        inStockOnly: true,
        sellByLengthOnly: true,
        minRating: 4.5,
      );
      final cleared = filters.copyWith(clearFabricFilters: true);
      expect(cleared.query, 'cot');
      expect(cleared.weight, FabricWeight.any);
      expect(cleared.width, FabricWidth.any);
      expect(cleared.fabricKeyword, isEmpty);
      expect(cleared.inStockOnly, isFalse);
      expect(cleared.sellByLengthOnly, isFalse);
      expect(cleared.minRating, 0);
      expect(cleared.hasActiveFilters, isTrue); // query still active
    });

    test('new fields participate in value equality (memo key)', () {
      expect(const CatalogFilters(),
          isNot(const CatalogFilters(weight: FabricWeight.light)));
      expect(
          const CatalogFilters(weight: FabricWeight.light),
          const CatalogFilters(
              weight: FabricWeight.light)); // equal → memo reuse
    });
  });
}
