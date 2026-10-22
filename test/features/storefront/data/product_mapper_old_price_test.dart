import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A row that carries `old_price` must map it onto the entity — the
/// discount badge and the strike-through price both read it.
void main() {
  test('a row with an old price maps the discounted price through', () {
    final product = ProductCodec.fromRow(
      {
        'id': 'p1',
        'name': 'Royal Silk',
        'base_price': 1000,
        'old_price': 1500,
        'categories': {'name': 'Silk'},
        'product_variants': [],
        'product_images': [],
      },
      [],
      storageService: StorageService(client: null),
    );

    expect(product, isNotNull);
    expect(product!.oldPrice, isNotNull);
    expect(product.oldPrice!.minorUnits, 1500);
    expect(product.price.minorUnits, 1000);
  });
}
