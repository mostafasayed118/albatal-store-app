import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mistyped description degrades to null instead of throwing', () {
    final product = ProductCodec.fromRow(
      {
        'id': 'p1',
        'name': 'Cotton',
        'base_price': 1000,
        'description': 42,
        'composition': ['cotton'],
        'care': 3.5,
        'origin': {'country': 'Egypt'},
      },
      const [],
      storageService: _FakeStorageService(),
    )!;

    expect(product.description, isNull);
    expect(product.composition, isNull);
    expect(product.care, isNull);
    expect(product.origin, isNull);
  });

  test('mistyped sort_order degrades and orders sanely instead of throwing',
      () {
    final product = ProductCodec.fromRow(
      {
        'id': 'p1',
        'name': 'Cotton',
        'base_price': 1000,
        'product_images': [
          {'storage_path': 'c.svg', 'sort_order': 2},
          {'storage_path': 'b.svg', 'sort_order': 1.5},
          {'storage_path': 'a.svg', 'sort_order': 'first'},
        ],
      },
      const [],
      storageService: _FakeStorageService(),
    )!;

    expect(product.images, ['cdn:a.svg', 'cdn:b.svg', 'cdn:c.svg']);
  });

  test('mistyped storage_path is skipped instead of throwing', () {
    final product = ProductCodec.fromRow(
      {
        'id': 'p1',
        'name': 'Cotton',
        'base_price': 1000,
        'product_images': [
          {'storage_path': 42, 'sort_order': 0},
          {'storage_path': 'ok.svg', 'sort_order': 0},
        ],
      },
      const [],
      storageService: _FakeStorageService(),
    )!;

    expect(product.images, ['cdn:ok.svg']);
  });

  test('mistyped review_count degrades instead of throwing', () {
    final fromDouble = ProductCodec.fromRow(
      {'id': 'p1', 'name': 'Cotton', 'base_price': 1000, 'review_count': 4.5},
      const [],
      storageService: _FakeStorageService(),
    )!;
    expect(fromDouble.reviewCount, 4);

    final fromString = ProductCodec.fromRow(
      {
        'id': 'p1',
        'name': 'Cotton',
        'base_price': 1000,
        'review_count': 'lots'
      },
      const [],
      storageService: _FakeStorageService(),
    )!;
    expect(fromString.reviewCount, 0);
  });

  test('mistyped rating degrades to 0.0 instead of throwing', () {
    final product = ProductCodec.fromRow(
      {'id': 'p1', 'name': 'Cotton', 'base_price': 1000, 'rating': 'superb'},
      const [],
      storageService: _FakeStorageService(),
    )!;
    expect(product.rating, 0.0);

    final wellTyped = ProductCodec.fromRow(
      {'id': 'p1', 'name': 'Cotton', 'base_price': 1000, 'rating': 4.5},
      const [],
      storageService: _FakeStorageService(),
    )!;
    expect(wellTyped.rating, 4.5);
  });

  test('missing optional fields stay null and missing id returns null', () {
    final product = ProductCodec.fromRow(
      {'id': 'p1', 'name': 'Cotton', 'base_price': 1000},
      const [],
      storageService: _FakeStorageService(),
    )!;

    expect(product.description, isNull);
    expect(product.composition, isNull);
    expect(product.care, isNull);
    expect(product.origin, isNull);
    expect(product.rating, 0.0);
    expect(product.reviewCount, 0);

    final storage = _FakeStorageService();
    expect(
      ProductCodec.fromRow(
        {'name': 'Cotton', 'base_price': 1000},
        const [],
        storageService: storage,
      ),
      isNull,
    );
    expect(
      ProductCodec.fromRow(
        {'id': 42, 'name': 'Cotton', 'base_price': 1000},
        const [],
        storageService: storage,
      ),
      isNull,
    );
  });
}

final class _FakeStorageService extends StorageService {
  @override
  String getProductImageUrl(String storagePath) => 'cdn:$storagePath';
}
