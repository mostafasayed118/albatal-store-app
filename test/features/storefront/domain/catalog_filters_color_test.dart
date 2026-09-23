import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-21 M-03: the filter chips gained the curated
/// `products.color_name` vocabulary — the matcher must accept BOTH
/// vocabularies or a curated chip can never match anything.
void main() {
  const product = Product(
    id: 'p1',
    name: 'Thobe',
    category: 'Silk',
    price: Money.egp(100),
    imageColor: 0xFF176B57,
    colorName: 'Sand',
    colors: ['Emerald'],
  );

  group('CatalogFilters.matches — curated colorName vocabulary', () {
    test('a chip sourced from colorName matches', () {
      expect(const CatalogFilters(colorFilter: 'Sand').matches(product), isTrue);
    });

    test('a chip sourced from the variant colors still matches', () {
      expect(
          const CatalogFilters(colorFilter: 'Emerald').matches(product), isTrue);
    });

    test('an unrelated chip does not match', () {
      expect(const CatalogFilters(colorFilter: 'Gold').matches(product), isFalse);
    });

    test('an empty filter matches everything', () {
      expect(const CatalogFilters().matches(product), isTrue);
    });
  });
}