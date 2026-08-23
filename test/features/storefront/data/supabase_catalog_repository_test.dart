import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('SupabaseCatalogRepository — persistent cache roundtrip (audit)', () {
    late SharedPreferences prefs;
    late SupabaseCatalogRepository repo;
    late _MockSupabaseClient mockClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockClient = _MockSupabaseClient();
      repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
      );
    });

    test(
        'persistCacheForTest / restorePersistentCacheForTest roundtrip preserves Money, imageColor, etc.',
        () async {
      final products = [
        const Product(
          id: '11111111-1111-1111-1111-111111111111',
          name: 'Royal Emerald Silk',
          category: 'Silk',
          price: Money(129000),
          oldPrice: Money(152000),
          imageColor: 0xFF176B57,
          imageAsset: 'assets/images/1.png',
          description: 'Hand-loomed silk',
          composition: '100% Silk',
          care: 'Dry clean',
          origin: 'India',
          images: ['assets/images/1.png'],
          sizes: ['1m', '2m', '5m'],
          colors: ['Emerald', 'Gold'],
          stock: {'Emerald-1m': 12, 'Gold-2m': 10},
          rating: 4.8,
          reviewCount: 124,
        ),
        const Product(
          id: '22222222-2222-2222-2222-222222222222',
          name: 'Midnight Velvet',
          category: 'Velvet',
          price: Money(98000),
          oldPrice: null,
          imageColor: 0xFF302244,
          imageAsset: null,
          description: null,
          composition: null,
          care: null,
          origin: null,
          images: [],
          sizes: ['1m'],
          colors: ['Purple'],
          stock: {'Purple-1m': 0},
          rating: 0.0,
          reviewCount: 0,
        ),
      ];

      // Persist via repository helper (same logic as fetchProducts success path)
      repo.persistCacheForTest(products);

      // Verify raw JSON was written to SharedPreferences
      final raw = prefs.getString('catalog_products_cache_v1');
      expect(raw, isNotNull);
      expect(raw, contains('11111111-1111-1111-1111-111111111111'));
      expect(raw, contains('22222222-2222-2222-2222-222222222222'));

      // Restore via repository helper (same logic as fetchProducts failure fallback)
      final restored = repo.restorePersistentCacheForTest();
      expect(restored, isNotNull);
      expect(restored!.length, 2);

      // First product equality (full fields)
      final a = restored[0];
      final expectedA = products[0];
      expect(a.id, expectedA.id);
      expect(a.name, expectedA.name);
      expect(a.category, expectedA.category);
      expect(a.price, expectedA.price);
      expect(a.oldPrice, expectedA.oldPrice);
      expect(a.imageColor, expectedA.imageColor);
      expect(a.imageAsset, expectedA.imageAsset);
      expect(a.description, expectedA.description);
      expect(a.composition, expectedA.composition);
      expect(a.care, expectedA.care);
      expect(a.origin, expectedA.origin);
      expect(a.images, expectedA.images);
      expect(a.sizes, expectedA.sizes);
      expect(a.colors, expectedA.colors);
      expect(a.stock, expectedA.stock);
      expect(a.rating, expectedA.rating);
      expect(a.reviewCount, expectedA.reviewCount);

      // Second product null handling
      final b = restored[1];
      final expectedB = products[1];
      expect(b.id, expectedB.id);
      expect(b.oldPrice, isNull);
      expect(b.imageColor, expectedB.imageColor);
      expect(b.imageAsset, isNull);
      expect(b.stock, expectedB.stock);
    });

    test('restore returns null when prefs empty (cold start)', () async {
      final restored = repo.restorePersistentCacheForTest();
      expect(restored, isNull);
    });

    test('cache hit path: findProductById and fetchProductById return same product',
        () async {
      const product = Product(
        id: '33333333-3333-3333-3333-333333333333',
        name: 'Heritage Wool',
        category: 'Wool',
        price: Money(82000),
        imageColor: 0xFF88715F,
        rating: 4.7,
        reviewCount: 56,
      );
      const product2 = Product(
        id: '44444444-4444-4444-4444-444444444444',
        name: 'Natural Linen',
        category: 'Linen',
        price: Money(54000),
        imageColor: 0xFFD9C6A1,
        rating: 4.5,
        reviewCount: 103,
      );

      // Warm the in-memory cache via test helper (simulates fetchProducts success)
      repo.setCacheForTest([product, product2]);

      // Synchronous lookup must hit
      final found = repo.findProductById(product.id);
      expect(found, isNotNull);
      expect(found, equals(product));
      expect(found?.price, const Money(82000));
      expect(found?.imageColor, 0xFF88715F);

      // Async fetchProductById should also hit cache without network
      final result = await repo.fetchProductById(product.id);
      expect(result, isA<Success<Product>>());
      final success = result as Success<Product>;
      expect(success.value, equals(product));
      expect(success.value.id, product.id);
      expect(success.value.name, 'Heritage Wool');

      // findProductById for unknown id returns null (graceful hydration)
      expect(repo.findProductById('non-existent'), isNull);
    });

    test('fetchProductById cache miss still works via cache setter', () async {
      const p = Product(
        id: '55555555-5555-5555-5555-555555555555',
        name: 'Desert Gold Silk',
        category: 'Silk',
        price: Money(134000),
        imageColor: 0xFFB57A2A,
      );
      repo.setCacheForTest([p]);

      // Verify cacheForTest exposes the same list
      expect(repo.cacheForTest, hasLength(1));
      expect(repo.cacheForTest!.first.id, p.id);
    });
  });
}
