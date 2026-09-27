import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeStorageService extends StorageService {
  _FakeStorageService() : super(client: null);
  @override
  String getProductImageUrl(String storagePath) => 'cdn:$storagePath';
}

Map<String, dynamic> get _row => {
      'id': 'p1',
      'name': 'Cotton',
      'categories': {'name': 'Cotton'},
      'base_price': 20000,
      'product_images': [],
    };

Map<String, dynamic> _variant(String size, String color, int stock,
        {bool? remnant}) =>
    {
      'size': size,
      'color': color,
      'stock': stock,
      if (remnant != null) 'is_remnant': remnant,
    };

Product _product(
        {Set<String> remnants = const {},
        Map<String, int> stock = const {'Emerald-1m': 2}}) =>
    Product(
      id: 'p1',
      name: 'Cotton',
      category: 'Cotton',
      price: const Money(20000),
      imageColor: 0,
      stock: stock,
      remnants: remnants,
    );

void main() {
  group('mapper — is_remnant (076)', () {
    test('productSelect fetches the flag', () {
      expect(ProductCodec.productSelect, contains('is_remnant'));
    });

    test('fromRow collects flagged variant keys', () {
      final product = ProductCodec.fromRow(
        _row,
        [
          _variant('1m', 'Emerald', 2, remnant: true),
          _variant('5m', 'Emerald', 9, remnant: false),
        ],
        storageService: _FakeStorageService(),
      );
      expect(product, isNotNull);
      expect(product!.remnants, {'Emerald-1m'});
      expect(product.hasRemnant, isTrue);
    });

    test('fromRow degrades missing flag to empty (pre-076 rows)', () {
      final product = ProductCodec.fromRow(
        _row,
        [_variant('1m', 'Emerald', 2)],
        storageService: _FakeStorageService(),
      );
      expect(product, isNotNull);
      expect(product!.remnants, isEmpty);
      expect(product.hasRemnant, isFalse);
    });

    test('encode/decode round-trips remnants; old caches decode empty', () {
      const flagged = Product(
        id: 'p1',
        name: 'Cotton',
        category: 'Cotton',
        price: Money(20000),
        imageColor: 0,
        stock: {'Emerald-1m': 2},
        remnants: {'Emerald-1m'},
      );
      final decoded = ProductCodec.decode(ProductCodec.encode(flagged));
      expect(decoded, flagged);
      expect(decoded!.hasRemnant, isTrue);

      final legacy = ProductCodec.decode({
        'id': 'p1',
        'stock': {'Emerald-1m': 2},
      });
      expect(legacy, isNotNull);
      expect(legacy!.remnants, isEmpty);
    });
  });

  group('entity — hasRemnant', () {
    test('sold-out flagged variant does not badge', () {
      expect(
        _product(
          remnants: {'Emerald-1m'},
          stock: const {'Emerald-1m': 0, 'Emerald-5m': 4},
        ).hasRemnant,
        isFalse,
      );
    });

    test('unflagged stock is not a remnant', () {
      expect(_product().hasRemnant, isFalse);
    });
  });

  group('filters — remnantsOnly', () {
    test('default is inert and inactive', () {
      const filters = CatalogFilters();
      expect(filters.remnantsOnly, isFalse);
      expect(filters.hasActiveFilters, isFalse);
      // Pre-076 products (no flags) match the default grid.
      expect(filters.matches(_product()), isTrue);
    });

    test('remnantsOnly keeps only in-stock flagged products', () {
      const filters = CatalogFilters(remnantsOnly: true);
      expect(filters.hasActiveFilters, isTrue);
      expect(filters.matches(_product(remnants: {'Emerald-1m'})), isTrue);
      expect(filters.matches(_product()), isFalse);
      expect(
        filters.matches(_product(
          remnants: {'Emerald-1m'},
          stock: const {'Emerald-1m': 0},
        )),
        isFalse,
      );
    });

    test('copyWith sets it; equality distinguishes it', () {
      expect(
        const CatalogFilters().copyWith(remnantsOnly: true).remnantsOnly,
        isTrue,
      );
      expect(
        const CatalogFilters(),
        isNot(const CatalogFilters(remnantsOnly: true)),
      );
    });
  });
}
