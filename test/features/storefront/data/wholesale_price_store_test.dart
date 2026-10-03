import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/storefront/data/wholesale_price_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Terminal filter builder: records the server-side filters the store
/// applied and answers the await with [rows] (or throws [error]).
class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder({this.rows = const [], this.error});

  final List<Map<String, dynamic>> rows;
  final Object? error;
  final List<(String, String, Object?)> filters = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object? value) {
    filters.add(('eq', column, value));
    return this;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> inFilter(
      String column, List<dynamic> values) {
    filters.add(('in', column, values));
    return this;
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestList value) onValue,
      {Function? onError}) {
    final error = this.error;
    final future = error != null
        ? Future<PostgrestList>.error(error)
        : Future.value(PostgrestList.from(rows));
    return future.then(onValue, onError: onError);
  }
}

void main() {
  test('maps wholesale list rows to per-product minor-unit prices', () async {
    final client = _MockClient();
    final builder = _MockQueryBuilder();
    final filter = _FakeFilterBuilder(rows: [
      {'product_id': 'p1', 'price_minor': 8000},
      {'product_id': 'p2', 'price_minor': 12500},
    ]);
    when(() => client.from('wholesale_price_lists')).thenAnswer((_) => builder);
    when(() => builder.select('product_id, price_minor'))
        .thenAnswer((_) => filter);

    final prices =
        await SupabaseWholesalePriceSource(client).fetchWholesalePrices(
      const ['p1', 'p2', 'p3'],
    );

    expect(prices['p1'], const Money(8000));
    expect(prices['p2'], const Money(12500));
    expect(prices.containsKey('p3'), isFalse,
        reason: 'a product without a list row is simply absent');
    // Server-side tier pin: only wholesale rows are requested, and the
    // id filter travels to PostgREST (never a client-side scan).
    final tierPin = filter.filters.singleWhere((f) => f.$1 == 'eq');
    expect((tierPin.$2, tierPin.$3), ('tier', 'wholesale'));
    final idFilter = filter.filters.singleWhere((f) => f.$1 == 'in');
    expect(idFilter.$2, 'product_id');
    expect(idFilter.$3 as List<dynamic>,
        unorderedEquals(const ['p1', 'p2', 'p3']));
  });

  test('mistyped rows degrade to skips instead of corrupting the map',
      () async {
    final client = _MockClient();
    final builder = _MockQueryBuilder();
    final filter = _FakeFilterBuilder(rows: [
      {'product_id': 'p1', 'price_minor': 8000},
      {'product_id': 'bad', 'price_minor': 0},
      {'product_id': 'worse', 'price_minor': 'ninety'},
      {'price_minor': 5000},
    ]);
    when(() => client.from('wholesale_price_lists')).thenAnswer((_) => builder);
    when(() => builder.select('product_id, price_minor'))
        .thenAnswer((_) => filter);

    final prices = await SupabaseWholesalePriceSource(client)
        .fetchWholesalePrices(const ['p1', 'bad', 'worse']);

    expect(prices.keys, ['p1']);
  });

  test('any error (RLS denial, pre-078 backend) degrades to an empty map',
      () async {
    final client = _MockClient();
    final builder = _MockQueryBuilder();
    final filter = _FakeFilterBuilder(
        error: const PostgrestException(
            message: 'row-level security', code: '42501'));
    when(() => client.from('wholesale_price_lists')).thenAnswer((_) => builder);
    when(() => builder.select('product_id, price_minor'))
        .thenAnswer((_) => filter);

    final prices = await SupabaseWholesalePriceSource(client)
        .fetchWholesalePrices(const ['p1']);

    expect(prices, isEmpty);
  });

  test('empty id sets skip the query entirely', () async {
    final client = _MockClient();
    final prices = await SupabaseWholesalePriceSource(client)
        .fetchWholesalePrices(const []);
    expect(prices, isEmpty);
    verifyNever(() => client.from(any()));
  });
}
