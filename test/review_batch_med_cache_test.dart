import 'dart:convert';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

const _good = Product(
  id: '11111111-1111-1111-1111-111111111111',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money(129000),
  imageColor: 0xFF176B57,
  sizes: ['1m', '2m'],
  colors: ['Emerald'],
  stock: {'Emerald-1m': 12},
  rating: 4.8,
  reviewCount: 124,
);

SupabaseCatalogRepository _repo(SharedPreferences prefs) =>
    SupabaseCatalogRepository(
      client: _MockSupabaseClient(),
      preferences: prefs,
    );

void main() {
  group('Persistent cache — per-item fail-soft (review-batch-med)', () {
    test('skips corrupt entries instead of discarding the whole cache',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final payload = [
        ProductCodec.encode(_good),
        // Missing id → decode returns null.
        {'name': 'Nameless', 'price': 100},
        // Mistyped imageColor (String, not num) → decode throws.
        {'id': 'bad-1', 'name': 'Bad Color', 'imageColor': 'red'},
        // Not a map at all.
        'just-a-string',
      ];
      await prefs.setString(
          'catalog_products_cache_v1', jsonEncode(payload));

      final restored = _repo(prefs).restorePersistentCacheForTest();
      expect(restored, isNotNull);
      expect(restored!.map((p) => p.id),
          ['11111111-1111-1111-1111-111111111111']);
    });

    test('garbage payload still restores to null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('catalog_products_cache_v1', 'not-json{{{');
      expect(_repo(prefs).restorePersistentCacheForTest(), isNull);
    });

    test('awaited persist round-trips the full product', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _repo(prefs);

      await repo.persistCacheForTest([_good]);

      final restored = repo.restorePersistentCacheForTest();
      expect(restored, hasLength(1));
      final product = restored!.single;
      expect(product.id, _good.id);
      expect(product.sizes, ['1m', '2m']);
      expect(product.colors, ['Emerald']);
      expect(product.stock, {'Emerald-1m': 12});
      expect(product.rating, 4.8);
      expect(product.reviewCount, 124);
    });
  });
}
