import 'dart:async';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._value);
  final T _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future.value(_value).whenComplete(action);
  }

  @override
  Stream<T> asStream() => Future.value(_value).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return Future.value(_value).timeout(timeLimit, onTimeout: onTimeout);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('adminUpsertProduct calls rpc with correct params and returns Result',
      () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('admin_upsert_product', params: any(named: 'params')))
        .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>('new-uuid'));
    final repo = SupabaseAdminRepository(client: client);
    final result = await repo.adminUpsertProduct(
      name: 'Thobe',
      slug: 'thobe',
      description: 'd',
      composition: 'cotton',
      categoryId: 'cat-1',
      basePrice: 100,
      isActive: true,
    );
    verify(() => client.rpc('admin_upsert_product', params: {
          'p_id': null,
          'p_name': 'Thobe',
          'p_slug': 'thobe',
          'p_description': 'd',
          'p_composition': 'cotton',
          'p_category_id': 'cat-1',
          'p_base_price': 100,
          'p_is_active': true,
        })).called(1);
    final value = result.when(success: (v) => v, failure: (e) => null);
    expect(value, 'new-uuid');
  });

  test('adminUpsertProduct returns Failure (never throws) when rpc fails',
      () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('admin_upsert_product', params: any(named: 'params')))
        .thenThrow(Exception('permission denied'));
    final repo = SupabaseAdminRepository(client: client);
    final result = await repo.adminUpsertProduct(
      name: 'Thobe',
      slug: 'thobe',
      categoryId: 'cat-1',
      basePrice: 100,
      isActive: true,
    );
    expect(result, isA<Failure<String>>());
  });

  test('adminUpsertVariant returns Failure when rpc returns a non-string',
      () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('admin_upsert_variant', params: any(named: 'params')))
        .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(42));
    final repo = SupabaseAdminRepository(client: client);
    final result = await repo.adminUpsertVariant(
      productId: 'p1',
      size: 'M',
      color: 'Navy',
      stock: 3,
    );
    expect(result, isA<Failure<String>>());
  });

  test('getAllProducts bounds the query with limit(100) + range page',
      () async {
    final client = MockSupabaseClient();
    final calls = <String>[];
    final transform = _AdminProductsTransform(calls);
    final filter = _AdminProductsFilter(calls, transform);
    when(() => client.from('products'))
        .thenAnswer((_) => _AdminProductsFrom(filter));
    final repo = SupabaseAdminRepository(client: client);
    final ok = await repo
        .getAllProducts()
        .then((r) => r.when(success: (_) => true, failure: (_) => false));
    expect(ok, isTrue);
    expect(calls, contains('order:name'));
    expect(calls, contains('limit:100'));
    expect(calls, contains('range:0-99'));
  });
}

/// Query-chain fakes that record every transform the admin repository
/// applies, so the bounded-load contract (`.order('name')` then
/// `.limit(100)` + `.range(0, 99)`) can be asserted. Future delegation
/// mirrors FakePostgrestFilterBuilder above.
class _AdminProductsFrom extends Fake implements SupabaseQueryBuilder {
  _AdminProductsFrom(this._filter);
  final _AdminProductsFilter _filter;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _filter;
}

class _AdminProductsFilter extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _AdminProductsFilter(this.calls, this._transform);
  final List<String> calls;
  final _AdminProductsTransform _transform;

  @override
  PostgrestFilterBuilder<PostgrestList> order(
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
    return _transform;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) {
    return Future.value(<Map<String, dynamic>>[])
        .then(onValue, onError: onError);
  }
}

class _AdminProductsTransform extends Fake
    implements PostgrestTransformBuilder<PostgrestList> {
  _AdminProductsTransform(this.calls);
  final List<String> calls;

  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    calls.add('range:$from-$to');
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) {
    return Future.value(<Map<String, dynamic>>[])
        .then(onValue, onError: onError);
  }
}
