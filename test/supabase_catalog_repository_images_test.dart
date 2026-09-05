import 'dart:async';

import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
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

      // Default storage mapping: return a deterministic public URL per path.
      when(() => mockStorage.getProductImageUrl(any())).thenAnswer((inv) {
        final path = inv.positionalArguments[0] as String;
        return 'https://mock.supabase.co/storage/v1/object/public/product-images/$path';
      });
    });

    test(
        'fetchProducts maps product_images to imageUrls via storage.getPublicUrl sorted by sort_order',
        () async {
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

      // Verify storage translation was invoked for each storage_path.
      verify(() => mockStorage.getProductImageUrl('product-images/p1/a.jpg'))
          .called(1);
      verify(() => mockStorage.getProductImageUrl('product-images/p1/b.jpg'))
          .called(1);

      // Image URLs must be sorted by sort_order ascending (a.jpg before b.jpg),
      // and passed through getProductImageUrl.
      expect(
        product.images,
        equals([
          'https://mock.supabase.co/storage/v1/object/public/product-images/product-images/p1/a.jpg',
          'https://mock.supabase.co/storage/v1/object/public/product-images/product-images/p1/b.jpg',
        ]),
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
      verifyNever(() => mockStorage.getProductImageUrl(any()));
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

      final sales = await repo.getActiveFlashSales();
      verify(() => mockClient.rpc('get_active_flash_sales')).called(1);
      expect(sales, hasLength(1));
      expect(sales.first['id'], 'fs1');
      expect(sales.first['discount_pct'], 15);
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

      final sales = await repo.getActiveFlashSales();
      expect(sales, isEmpty);
    });
  });
}
