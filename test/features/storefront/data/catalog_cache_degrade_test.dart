import 'dart:convert';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
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

/// Same category as [_good] — the related-strip fallback must include it.
const _sameCategory = Product(
  id: '22222222-2222-2222-2222-222222222222',
  name: 'Ivory Silk Charmeuse',
  category: 'Silk',
  price: Money(98000),
  imageColor: 0xFFF2EAD9,
  sizes: ['1m'],
  colors: ['Ivory'],
  stock: {'Ivory-1m': 5},
);

/// Different category — the related-strip fallback must exclude it.
const _other = Product(
  id: '33333333-3333-3333-3333-333333333333',
  name: 'Midnight Velvet',
  category: 'Velvet',
  price: Money(88000),
  imageColor: 0xFF302244,
  sizes: ['2m'],
  colors: ['Purple'],
  stock: {'Purple-2m': 7},
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
        // Mistyped imageColor (String, not num) → total decode degrades
        // the field (placeholder tint) instead of throwing; the entry
        // survives because it carries a usable id.
        {'id': 'bad-1', 'name': 'Bad Color', 'imageColor': 'red'},
        // Not a map at all.
        'just-a-string',
      ];
      await prefs.setString('catalog_products_cache_v1', jsonEncode(payload));

      final restored = _repo(prefs).restorePersistentCacheForTest();
      expect(restored, isNotNull);
      expect(restored!.map((p) => p.id), [
        '11111111-1111-1111-1111-111111111111',
        'bad-1',
      ]);
      // The mistyped imageColor degraded to the same placeholder an absent
      // imageColor decodes to — not thrown, not propagated.
      expect(
          restored.last.imageColor,
          ProductCodec.decode(
                  {'id': 'p', 'name': 'p', 'category': 'p', 'price': 0})!
              .imageColor);
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

  group('Offline degrades (Task #8)', () {
    test(
        'fetchProductById cold-start offline restores the persistent cache '
        'and resolves the id', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _MockSupabaseClient();
      final repo =
          SupabaseCatalogRepository(client: client, preferences: prefs);
      await repo.persistCacheForTest([_good, _other]);
      when(() => client.from(any())).thenThrow(Exception('network offline'));

      final result = await repo.fetchProductById(_good.id);

      expect(result, isA<Success<Product>>());
      expect((result as Success<Product>).value.id, _good.id);
      // The restore routed through _setCache — synchronous index rebuilt.
      expect(repo.findProductById(_good.id)?.name, 'Royal Emerald Silk');
    });

    test(
        'fetchProductById offline with a cold cache still fails (page shows '
        'the offline notice, not a stale product)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _MockSupabaseClient();
      final repo =
          SupabaseCatalogRepository(client: client, preferences: prefs);
      when(() => client.from(any())).thenThrow(Exception('network offline'));

      final result = await repo.fetchProductById(_good.id);

      expect(result, isA<Failure>());
    });

    test('fetchRelated offline derives the strip from the persistent cache',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _MockSupabaseClient();
      final repo =
          SupabaseCatalogRepository(client: client, preferences: prefs);
      // Two Silk products + one Velvet: the strip must filter + exclude.
      await repo.persistCacheForTest([_good, _sameCategory, _other]);
      when(() => client.from(any())).thenThrow(Exception('network offline'));

      final result =
          await repo.fetchRelated('Silk', excludeId: _good.id, limit: 8);

      expect(result, isA<Success<List<Product>>>());
      final related = (result as Success<List<Product>>).value;
      expect(related.map((p) => p.id), [_sameCategory.id]);
    });

    test('fetchRelated offline with nothing cached fails closed as before',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _MockSupabaseClient();
      final repo =
          SupabaseCatalogRepository(client: client, preferences: prefs);
      when(() => client.from(any())).thenThrow(Exception('network offline'));

      final result = await repo.fetchRelated('Silk');

      expect(result, isA<Failure>());
    });
  });
}
