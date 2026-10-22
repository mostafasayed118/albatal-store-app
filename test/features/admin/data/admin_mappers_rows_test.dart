import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/data/admin_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminMappers.variantsFromRows', () {
    test('maps id-bearing rows and skips non-map / id-less entries', () {
      final variants = AdminMappers.variantsFromRows([
        {
          'id': 'v-1',
          'size': 'M',
          'color': 'Navy',
          'stock': 4,
          'price_override': 12575,
        },
        'not-a-map',
        {'size': 'no-id'},
        {'id': '', 'size': 'blank id'},
      ]);

      expect(variants, hasLength(1));
      expect(variants.single.variantId, 'v-1');
      expect(variants.single.stock, 4);
      expect(variants.single.priceOverride, const Money(12575));
    });

    test('an empty payload maps to an empty list', () {
      expect(AdminMappers.variantsFromRows(const []), isEmpty);
    });
  });

  group('AdminMappers.imagePathsFromRows', () {
    test('keeps non-blank string paths and skips everything else', () {
      final paths = AdminMappers.imagePathsFromRows([
        {'storage_path': 'product-images/p/a.jpg'},
        {'storage_path': 'product-images/p/b.jpg'},
        {'storage_path': '   '},
        {'storage_path': null},
        {'storage_path': 7},
        'not-a-map',
      ]);

      expect(paths, [
        'product-images/p/a.jpg',
        'product-images/p/b.jpg',
      ]);
    });
  });

  group('AdminMappers.productFromRow price guards', () {
    test('a zero or negative price degrades to Money.zero', () {
      final zero = AdminMappers.productFromRow({
        'id': 'p-zero',
        'name': 'Zero',
        'base_price': 0,
      });
      final negative = AdminMappers.productFromRow({
        'id': 'p-negative',
        'name': 'Negative',
        'base_price': -5,
      });

      expect(zero.basePrice, Money.zero);
      expect(negative.basePrice, Money.zero);
    });

    test('an absurdly large price is clamped to Money.zero', () {
      final product = AdminMappers.productFromRow({
        'id': 'p-huge',
        'name': 'Huge',
        'base_price': 1000000000,
      });

      expect(product.basePrice, Money.zero);
    });

    test('a normal price is preserved as minor units', () {
      final product = AdminMappers.productFromRow({
        'id': 'p-ok',
        'name': 'Normal',
        'base_price': 189000,
      });

      expect(product.basePrice, const Money.egp(1890));
    });
  });
}
