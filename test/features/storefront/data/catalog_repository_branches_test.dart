import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.chain);

  final _FakeChain chain;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) => chain;
}

class _FakeChain extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  _FakeChain(
    this.rows, {
    this.singleRow,
    this.error,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? singleRow;
  final Object? error;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    calls.add('eq:$column');
    return this;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> neq(String column, Object value) {
    calls.add('neq:$column');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    calls.add('order:$column');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) {
    calls.add('limit:$count');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap> single() =>
      _FakeSingle(singleRow, error);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) {
    if (error != null) {
      return Future<PostgrestList>.error(error!)
          .then(onValue, onError: onError);
    }
    return Future<PostgrestList>.value(rows).then(onValue, onError: onError);
  }
}

class _FakeSingle extends Fake
    implements PostgrestTransformBuilder<PostgrestMap> {
  _FakeSingle(this.row, this.error);

  final Map<String, dynamic>? row;
  final Object? error;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap value) onValue, {
    Function? onError,
  }) {
    if (error != null) {
      return Future<PostgrestMap>.error(error!).then(onValue, onError: onError);
    }
    return Future<PostgrestMap>.value(row ?? const {})
        .then(onValue, onError: onError);
  }
}

Map<String, dynamic> _row({
  String id = 'p1',
  String name = 'Royal Silk',
  String category = 'Silk',
  int price = 129000,
}) =>
    {
      'id': id,
      'name': name,
      'base_price': price,
      'categories': {'name': category},
      'product_variants': [],
      'product_images': [],
    };

void main() {
  late SharedPreferences prefs;
  late _MockClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    client = _MockClient();
  });

  SupabaseCatalogRepository repo() =>
      SupabaseCatalogRepository(client: client, preferences: prefs);

  group('SupabaseCatalogRepository.fetchProducts cache branches', () {
    test('a second call inside the TTL serves the in-memory cache', () async {
      final chain = _FakeChain([_row()]);
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final catalog = repo();
      final first = await catalog.fetchProducts();
      final second = await catalog.fetchProducts();

      expect(first, isA<Success<List<Product>>>());
      expect(second, isA<Success<List<Product>>>());
      expect(
          identical((first as Success<List<Product>>).value,
              (second as Success<List<Product>>).value),
          isTrue);
      verify(() => client.from('products')).called(1);
    });

    test('cold start with no cache and no network fails with the load code',
        () async {
      when(() => client.from('products')).thenThrow(Exception('offline'));

      final result = await repo().fetchProducts();

      expect(result, isA<Failure<List<Product>>>());
      expect((result as Failure).error.code, kFailureLoad);
    });

    test(
        'custom limit is over-fetched by one and empty pages are not truncated',
        () async {
      final chain = _FakeChain(const []);
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final catalog = repo();
      final result = await catalog.fetchProducts(limit: 5);

      expect((result as Success<List<Product>>).value, isEmpty);
      expect(chain.calls, contains('order:name'));
      expect(chain.calls, contains('limit:6'));
      expect(catalog.lastPageTruncated, isFalse);
    });
  });

  group('SupabaseCatalogRepository.fetchCategories', () {
    test('maps names and drops empty/non-string entries', () async {
      final chain = _FakeChain([
        {'name': 'Silk'},
        {'name': ''},
        {'name': 42},
        <String, dynamic>{},
      ]);
      when(() => client.from('categories'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().fetchCategories();

      expect((result as Success<List<String>>).value, ['Silk']);
      expect(chain.calls, contains('eq:is_active'));
      expect(chain.calls, contains('order:sort_order'));
    });

    test('a transport failure maps to the load failure code', () async {
      when(() => client.from('categories')).thenThrow(Exception('offline'));

      final result = await repo().fetchCategories();

      expect(result, isA<Failure<List<String>>>());
      expect((result as Failure).error.code, kFailureLoad);
    });
  });

  group('SupabaseCatalogRepository.fetchProductById', () {
    test('fetches and maps a single row on a cache miss', () async {
      final chain = _FakeChain(const [], singleRow: _row(id: 'p9'));
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().fetchProductById('p9');

      expect(result, isA<Success<Product>>());
      final product = (result as Success<Product>).value;
      expect(product.id, 'p9');
      expect(product.name, 'Royal Silk');
      expect(product.price.minorUnits, 129000);
      expect(chain.calls, contains('eq:id'));
    });

    test('a row without a usable name fails closed', () async {
      final chain = _FakeChain(const [], singleRow: {'id': 'p9'});
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().fetchProductById('p9');

      expect(result, isA<Failure<Product>>());
      expect((result as Failure).error.code, kFailureLoad);
    });

    test('single() not-found maps to the not-found code', () async {
      final chain = _FakeChain(
        const [],
        error: const PostgrestException(
            message: 'JSON object requested, multiple (or no) rows returned',
            code: 'PGRST116'),
      );
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().fetchProductById('missing');

      expect(result, isA<Failure<Product>>());
      expect((result as Failure).error.code, kFailureNotFound);
    });

    test('offline cold start restores the persistent cache for the id',
        () async {
      const cached = Product(
        id: 'p9',
        name: 'Cached Silk',
        category: 'Silk',
        price: Money(1000),
        imageColor: 0xFF176B57,
      );
      final catalog = repo();
      await catalog.persistCacheForTest([cached]);
      when(() => client.from('products')).thenThrow(Exception('offline'));

      final result = await catalog.fetchProductById('p9');

      expect(result, isA<Success<Product>>());
      expect((result as Success<Product>).value.name, 'Cached Silk');
    });

    test('offline without a persistent cache fails with the load code',
        () async {
      when(() => client.from('products')).thenThrow(Exception('offline'));

      final result = await repo().fetchProductById('p9');

      expect(result, isA<Failure<Product>>());
      expect((result as Failure).error.code, kFailureLoad);
    });
  });

  group('SupabaseCatalogRepository.fetchRelated', () {
    test('filters server-side and excludes the current product', () async {
      final chain = _FakeChain([
        _row(id: 'p2', name: 'Second Silk'),
        _row(id: 'p3', name: 'Third Silk'),
      ]);
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result =
          await repo().fetchRelated('Silk', excludeId: 'p1', limit: 3);

      expect(result, isA<Success<List<Product>>>());
      expect((result as Success<List<Product>>).value.map((p) => p.id),
          ['p2', 'p3']);
      expect(chain.calls, contains('eq:is_active'));
      expect(chain.calls, contains('eq:categories.name'));
      expect(chain.calls, contains('neq:id'));
      expect(chain.calls, contains('order:name'));
      expect(chain.calls, contains('limit:3'));
    });

    test('an empty exclude id skips the neq filter', () async {
      final chain = _FakeChain([_row(id: 'p2')]);
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().fetchRelated('Silk', excludeId: '');

      expect(result, isA<Success<List<Product>>>());
      expect(chain.calls, isNot(contains('neq:id')));
    });

    test('an empty category short-circuits to an empty success', () async {
      final result = await repo().fetchRelated('');

      expect(result, isA<Success<List<Product>>>());
      expect((result as Success<List<Product>>).value, isEmpty);
      verifyNever(() => client.from(any()));
    });

    test('a transport failure derives the strip from the in-memory cache',
        () async {
      final chain = _FakeChain([
        _row(id: 'p1', category: 'Silk'),
        _row(id: 'p2', category: 'Silk'),
        _row(id: 'p3', category: 'Wool'),
      ]);
      when(() => client.from('products'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));
      final catalog = repo();
      await catalog.fetchProducts();

      when(() => client.from('products')).thenThrow(Exception('offline'));
      final result = await catalog.fetchRelated('Silk', excludeId: 'p1');

      expect(result, isA<Success<List<Product>>>());
      expect((result as Success<List<Product>>).value.map((p) => p.id), ['p2']);
    });

    test('a transport failure with nothing cached fails closed', () async {
      when(() => client.from('products')).thenThrow(Exception('offline'));

      final result = await repo().fetchRelated('Silk');

      expect(result, isA<Failure<List<Product>>>());
      expect((result as Failure).error.code, kFailureLoad);
    });
  });

  test('defaultCategories delegates to the domain const', () {
    expect(repo().defaultCategories, defaultCatalogCategories);
  });
}
