import 'dart:async';

import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/admin_wholesale_prices_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

T? _value<T>(Result<T> result) => switch (result) {
      Success<T>(:final value) => value,
      Failure<T>() => null,
    };

AppError? _error<T>(Result<T> result) => switch (result) {
      Success<T>() => null,
      Failure<T>(:final error) => error,
    };

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
  Future<R> then<R>(FutureOr<R> Function(PostgrestList value) onValue,
      {Function? onError}) {
    final error = this.error;
    final future = error != null
        ? Future<PostgrestList>.error(error)
        : Future.value(PostgrestList.from(rows));
    return future.then(onValue, onError: onError);
  }
}

/// Terminal builder for rpc calls: records the params and answers with
/// [error] (or void success).
class _FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<void> {
  _FakeRpcBuilder({this.error});

  final Object? error;

  @override
  Future<R> then<R>(FutureOr<R> Function(void value) onValue,
      {Function? onError}) {
    final error = this.error;
    return (error != null
            ? Future<void>.error(error)
            : Future<void>.value(null))
        .then(onValue, onError: onError);
  }
}

void main() {
  test('maps price-list rows with the product embed, sorted by name', () async {
    final client = _MockClient();
    final builder = _MockQueryBuilder();
    final filter = _FakeFilterBuilder(rows: [
      {
        'product_id': 'p2',
        'tier': 'wholesale',
        'price_minor': 9000,
        'updated_at': '2026-10-01T10:00:00Z',
        'products': {'name': 'Linen'},
      },
      {
        'product_id': 'p1',
        'tier': 'wholesale',
        'price_minor': 15000,
        'updated_at': '2026-10-02T10:00:00Z',
        'products': {'name': 'Silk'},
      },
      {'price_minor': 5000},
    ]);
    when(() => client.from('wholesale_price_lists')).thenAnswer((_) => builder);
    when(() => builder.select(
            'product_id, tier, price_minor, updated_at, products(name)'))
        .thenAnswer((_) => filter);

    final result = await SupabaseAdminWholesalePrices(client: client)
        .fetchWholesalePrices();

    final entries = _value(result)!;
    expect(entries.map((e) => e.productName).toList(), ['Linen', 'Silk'],
        reason: 'client-side name sort — the picker reads like the catalog');
    expect(entries.first.priceMinor, 9000);
    expect(entries.first.updatedAt, DateTime.utc(2026, 10, 1, 10));
    final tierPin = filter.filters.singleWhere((f) => f.$1 == 'eq');
    expect((tierPin.$2, tierPin.$3), ('tier', 'wholesale'));
  });

  test('a missing product embed degrades to the product id', () async {
    final client = _MockClient();
    final builder = _MockQueryBuilder();
    final filter = _FakeFilterBuilder(rows: [
      {
        'product_id': 'p1',
        'price_minor': 15000,
        'products': null,
      },
    ]);
    when(() => client.from('wholesale_price_lists')).thenAnswer((_) => builder);
    when(() => builder.select(
            'product_id, tier, price_minor, updated_at, products(name)'))
        .thenAnswer((_) => filter);

    final result = await SupabaseAdminWholesalePrices(client: client)
        .fetchWholesalePrices();

    expect(_value(result)!.single.productName, 'p1');
  });

  test('load failure (RLS denial) is a Failure with the machine code',
      () async {
    final client = _MockClient();
    final builder = _MockQueryBuilder();
    final filter = _FakeFilterBuilder(
        error: const PostgrestException(
            message: 'row-level security', code: '42501'));
    when(() => client.from('wholesale_price_lists')).thenAnswer((_) => builder);
    when(() => builder.select(
            'product_id, tier, price_minor, updated_at, products(name)'))
        .thenAnswer((_) => filter);

    final result = await SupabaseAdminWholesalePrices(client: client)
        .fetchWholesalePrices();

    expect(_error(result)?.code, kAdminWholesalePricesLoadFailed);
  });

  test('upsert rpc carries product id + minor price, guards pre-flight',
      () async {
    final client = _MockClient();
    final rpc = _FakeRpcBuilder();
    when(() => client.rpc('admin_upsert_wholesale_price',
        params: any(named: 'params'))).thenAnswer((_) => rpc);

    final store = SupabaseAdminWholesalePrices(client: client);
    final bad = await store.upsertWholesalePrice(productId: '', priceMinor: 0);
    expect(_error(bad), isNotNull);
    verifyNever(() => client.rpc('admin_upsert_wholesale_price',
        params: any(named: 'params')));

    final good =
        await store.upsertWholesalePrice(productId: 'p1', priceMinor: 15000);
    expect(good, isA<Success<void>>());
    final captured = verify(() => client.rpc('admin_upsert_wholesale_price',
            params: captureAny(named: 'params'))).captured.single
        as Map<String, dynamic>;
    expect(captured['p_product_id'], 'p1');
    expect(captured['p_price_minor'], 15000);
    expect(captured.containsKey('p_tier'), isFalse,
        reason: 'the server defaults the tier — the client never pins it');
  });

  test('upsert rpc failure keeps the upsert machine code', () async {
    final client = _MockClient();
    final rpc = _FakeRpcBuilder(
        error:
            const PostgrestException(message: 'invalid_price', code: '22023'));
    when(() => client.rpc('admin_upsert_wholesale_price',
        params: any(named: 'params'))).thenAnswer((_) => rpc);

    final result = await SupabaseAdminWholesalePrices(client: client)
        .upsertWholesalePrice(productId: 'p1', priceMinor: 15000);

    expect(_error(result)?.code, kAdminWholesalePriceUpsertFailed);
  });

  test('delete rpc carries the product id and keeps its machine code',
      () async {
    final client = _MockClient();
    final rpc = _FakeRpcBuilder(
        error: const PostgrestException(message: 'not found', code: 'P0002'));
    when(() => client.rpc('admin_delete_wholesale_price',
        params: any(named: 'params'))).thenAnswer((_) => rpc);

    final result = await SupabaseAdminWholesalePrices(client: client)
        .deleteWholesalePrice('p1');

    expect(_error(result)?.code, kAdminWholesalePriceDeleteFailed);
    final captured = verify(() => client.rpc('admin_delete_wholesale_price',
            params: captureAny(named: 'params'))).captured.single
        as Map<String, dynamic>;
    expect(captured['p_product_id'], 'p1');
  });
}
