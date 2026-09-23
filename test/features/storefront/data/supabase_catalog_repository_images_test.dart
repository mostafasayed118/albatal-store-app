import 'dart:async';

import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Fakes / Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockStorageService extends Mock implements StorageService {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._value);
  final T _value;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestTransformBuilder<T> limit(
    int count, {
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestFilterBuilder<T> not(
    String column,
    String operator,
    Object? value,
  ) =>
      this;

  @override
  PostgrestFilterBuilder<T> or(
    String filters, {
    String? referencedTable,
  }) =>
      this;

  // --- Future<T> delegation so `await builder` works -----------------------

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return Future.value(_value).catchError(onError, test: test);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future.value(_value).whenComplete(action);
  }

  @override
  Stream<T> asStream() => Future.value(_value).asStream();

  @override
  Future<T> timeout(
    Duration timeLimit, {
    FutureOr<T> Function()? onTimeout,
  }) {
    return Future.value(_value).timeout(timeLimit, onTimeout: onTimeout);
  }
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  FakeSupabaseQueryBuilder(this._builder);
  final PostgrestFilterBuilder<PostgrestList> _builder;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _builder;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue('');
  });

  group('SupabaseCatalogRepository — product_images + flash sales (T1)', () {
    late MockSupabaseClient mockClient;
    late MockStorageService mockStorage;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockClient = MockSupabaseClient();
      mockStorage = MockStorageService();

      // Default storage mapping: a deterministic RENDER URL per (path, width).
      // The width is echoed into the URL so the assertions below pin the budget
      // each surface asked for, not just the mapping.
      when(() => mockStorage.getProductImageUrlForWidth(any(), any()))
          .thenAnswer((inv) {
        final path = inv.positionalArguments[0] as String;
        final width = inv.positionalArguments[1] as int;
        return 'https://mock.supabase.co/storage/v1/render/image/public/'
            'product-images/$path?width=$width';
      });
    });

    test(
        'fetchProducts maps product_images to width-bounded render URLs sorted '
        'by sort_order (420 primary, 720 detail)', () async {
      // Arrange: one product row with two images out of order to verify sorting.
      final rows = <Map<String, dynamic>>[
        {
          'id': 'p1',
          'name': 'Thobe',
          'slug': 'thobe',
          'description': 'desc',
          'composition': 'cotton',
          'care': 'care',
          'origin': 'EG',
          'base_price': 10000,
          'old_price': null,
          'rating': 4.5,
          'review_count': 10,
          'categories': {'name': 'Cotton'},
          'product_variants': [
            {
              'product_id': 'p1',
              'size': 'M',
              'color': 'Emerald',
              'stock': 5,
              'price_override': null,
            },
          ],
          // Intentionally reversed sort_order to ensure repository sorts.
          'product_images': [
            {'storage_path': 'product-images/p1/b.jpg', 'sort_order': 1},
            {'storage_path': 'product-images/p1/a.jpg', 'sort_order': 0},
          ],
        },
      ];
      final fakeBuilder =
          FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(rows);

      when(() => mockClient.from('products'))
          .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeBuilder));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      // Act
      final result = await repo.fetchProducts();

      // Assert: repository returned Success and mapped images correctly.
      expect(result, isA<Success<List<Product>>>());
      final typed = (result as Success<List<Product>>).value;
      expect(typed, hasLength(1));
      final product = typed.first;
      expect(product.id, 'p1');

      // Every storage_path resolves at the DETAIL budget only — the primary
      // shares the gallery's budget so one photo = one cache key (audit
      // 2026-09-21 dual-cache finding). a.jpg is asked twice (gallery entry
      // + primary); no grid-budget request may ever fire.
      verify(() => mockStorage.getProductImageUrlForWidth(
            'product-images/p1/a.jpg',
            StorageService.detailImageWidth,
          )).called(2);
      verify(() => mockStorage.getProductImageUrlForWidth(
            'product-images/p1/b.jpg',
            StorageService.detailImageWidth,
          )).called(1);
      verifyNever(() => mockStorage.getProductImageUrlForWidth(
          any(), StorageService.gridImageWidth));

      // Image URLs must be sorted by sort_order ascending (a.jpg before b.jpg)
      // at the detail budget...
      expect(
        product.images,
        equals([
          'https://mock.supabase.co/storage/v1/render/image/public/product-images/product-images/p1/a.jpg?width=720',
          'https://mock.supabase.co/storage/v1/render/image/public/product-images/product-images/p1/b.jpg?width=720',
        ]),
      );
      // ...and the card/thumbnail surface shares the DETAIL budget —
      // one URL string per photo = one cache entry (audit 2026-09-21);
      // the card still bounds its own decode via memCacheWidth.
      expect(
        product.imageAsset,
        'https://mock.supabase.co/storage/v1/render/image/public/product-images/product-images/p1/a.jpg?width=720',
      );

      // Placeholder fallback not misapplied — images not empty,
      // but imageColor remains the placeholder (spec: fallback only when empty).
      expect(product.imageColor, 0xFF888888);
    });

    test('fetchProducts fallback to empty images when product_images empty',
        () async {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'p2',
          'name': 'Bisht',
          'slug': 'bisht',
          'description': null,
          'composition': null,
          'care': null,
          'origin': null,
          'base_price': 20000,
          'old_price': null,
          'rating': null,
          'review_count': null,
          'categories': {'name': 'Wool'},
          'product_variants': [],
          'product_images': [],
        },
      ];

      final fakeBuilder =
          FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(rows);
      when(() => mockClient.from('products'))
          .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeBuilder));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      final result = await repo.fetchProducts();
      expect(result, isA<Success<List<Product>>>());
      final product = (result as Success<List<Product>>).value.first;
      expect(product.images, isEmpty);
      expect(product.imageColor, 0xFF888888);
      // No usable image -> no card source and no render-URL round trip.
      expect(product.imageAsset, isNull);
      verifyNever(() => mockStorage.getProductImageUrlForWidth(any(), any()));
    });

    test('fetchProducts handles missing product_images key as empty', () async {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'p3',
          'name': 'Kandura',
          'slug': 'kandura',
          'description': null,
          'composition': null,
          'care': null,
          'origin': null,
          'base_price': 15000,
          'old_price': null,
          'rating': null,
          'review_count': null,
          'categories': {'name': 'Silk'},
          'product_variants': [],
          // No product_images key at all — simulates older data.
        },
      ];

      final fakeBuilder =
          FakePostgrestFilterBuilder<List<Map<String, dynamic>>>(rows);
      when(() => mockClient.from('products'))
          .thenAnswer((_) => FakeSupabaseQueryBuilder(fakeBuilder));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      final result = await repo.fetchProducts();
      expect(result, isA<Success<List<Product>>>());
      expect((result as Success<List<Product>>).value.first.images, isEmpty);
    });

    test('getActiveFlashSales calls rpc get_active_flash_sales', () async {
      final rpcData = [
        {
          'id': 'fs1',
          'product_id': 'p1',
          'discount_pct': 15,
          'starts_at': '2026-08-24T00:00:00Z',
          'ends_at': '2026-08-25T00:00:00Z',
          'is_active': true,
        },
      ];

      when(() => mockClient.rpc('get_active_flash_sales'))
          .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(rpcData));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      final result = await repo.getActiveFlashSales();
      verify(() => mockClient.rpc('get_active_flash_sales')).called(1);
      expect(result, isA<Success<List<FlashSale>>>());
      final sales = (result as Success<List<FlashSale>>).value;
      expect(sales, hasLength(1));
      expect(sales.first.productId, 'p1');
      expect(sales.first.discountPct, 15);
      expect(sales.first.endsAt, DateTime.parse('2026-08-25T00:00:00Z'));
    });

    test('getActiveFlashSales returns empty list when rpc returns empty',
        () async {
      when(() => mockClient.rpc('get_active_flash_sales'))
          .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(<dynamic>[]));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      final result = await repo.getActiveFlashSales();
      expect(result, isA<Success<List<FlashSale>>>());
      expect((result as Success<List<FlashSale>>).value, isEmpty);
    });

    test('getActiveFlashSales skips rows without a product_id', () async {
      final rpcData = [
        {
          'id': 'fs-bad',
          'discount_pct': 50,
          'ends_at': '2026-08-25T00:00:00Z',
        },
        {
          'id': 'fs-good',
          'product_id': 'p1',
          'discount_pct': 15,
          'ends_at': '2026-08-25T00:00:00Z',
          'is_active': true,
        },
      ];

      when(() => mockClient.rpc('get_active_flash_sales'))
          .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(rpcData));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      final result = await repo.getActiveFlashSales();
      expect(result, isA<Success<List<FlashSale>>>());
      final sales = (result as Success<List<FlashSale>>).value;
      expect(sales, hasLength(1));
      expect(sales.first.productId, 'p1');
    });

    test('getActiveFlashSales fails closed when the rpc throws', () async {
      when(() => mockClient.rpc('get_active_flash_sales'))
          .thenThrow(Exception('transport down'));

      final repo = SupabaseCatalogRepository(
        client: mockClient,
        preferences: prefs,
        storageService: mockStorage,
      );

      final result = await repo.getActiveFlashSales();
      expect(result, isA<Failure<List<FlashSale>>>());
    });
  });
}
