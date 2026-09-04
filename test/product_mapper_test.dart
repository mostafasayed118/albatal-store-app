import 'package:flutter_test/flutter_test.dart';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';

void main() {
  test('encode/decode preserves every product field', () {
    const product = Product(
      id: 'silk-1',
      name: 'Silk',
      category: 'Silk',
      price: Money(129900),
      oldPrice: Money(149900),
      imageColor: 0xff123456,
      imageAsset: 'assets/images/silk.svg',
      images: ['https://example.test/1'],
      description: 'description',
      composition: 'silk',
      care: 'dry clean',
      origin: 'Egypt',
      sizes: ['2m'],
      colors: ['Emerald'],
      stock: {'Emerald-2m': 4},
      rating: 4.5,
      reviewCount: 12,
    );

    expect(ProductCodec.decode(ProductCodec.encode(product)), product);
    expect(ProductCodec.decode(ProductCodec.encode(product)).price.minorUnits,
        129900);
    expect(
        ProductCodec.decode(ProductCodec.encode(product)).oldPrice!.minorUnits,
        149900);
  });

  test('fromRow derives sorted variants and deterministically sorted images',
      () {
    final product = ProductCodec.fromRow(
      {
        'id': 'p1',
        'name': 'Cotton',
        'base_price': 50000,
        'old_price': null,
        'description': null,
        'composition': null,
        'care': null,
        'origin': null,
        'review_count': 0,
        'categories': {'name': 'Cotton'},
        'product_images': [
          {'storage_path': 'z-last.svg', 'sort_order': 2},
          {'storage_path': 'b-tied.svg', 'sort_order': 1},
          {'storage_path': 'a-tied.svg', 'sort_order': 1},
          {'storage_path': 'first.svg', 'sort_order': 0},
        ],
      },
      [
        {'size': 'XL', 'color': 'Ruby', 'stock': 3},
        {'size': 'M', 'color': 'Emerald', 'stock': 4},
        {'size': 'S', 'color': 'Ruby', 'stock': 5},
        {'size': 'M', 'color': 'Emerald', 'stock': 6},
      ],
      storageService: _FakeStorageService(),
    );

    expect(product.sizes, ['M', 'S', 'XL']);
    expect(product.colors, ['Emerald', 'Ruby']);
    expect(product.stock['Emerald-M'], 6);
    expect(product.stock['Ruby-S'], 5);
    expect(product.stock['Ruby-XL'], 3);
    expect(
      product.images,
      ['cdn:first.svg', 'cdn:a-tied.svg', 'cdn:b-tied.svg', 'cdn:z-last.svg'],
    );
    expect(product.category, 'Cotton');
    expect(product.price.minorUnits, 50000);
  });
}

final class _FakeStorageService extends StorageService {
  @override
  String getProductImageUrl(String storagePath) => 'cdn:$storagePath';
}
