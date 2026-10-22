import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/admin_catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// Rows chain that records the transforms the catalog port applies and
/// resolves to the planted rows when awaited (or throws [error]).
class _FakeRowsChain extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeRowsChain(this.rows);

  final List<dynamic> rows;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object? value) {
    calls.add('eq:$column:$value');
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
  }) =>
      Future.value(rows.cast<Map<String, dynamic>>())
          .then(onValue, onError: onError);
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.chain);

  final _FakeRowsChain chain;
  final List<String> selects = [];
  final List<Map<String, dynamic>> updates = [];

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    selects.add(columns);
    return chain;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> update(Map values) {
    updates.add(Map<String, dynamic>.from(values));
    return chain;
  }
}

/// Awaitable RPC payload (the catalog port only checks the returned id).
class _FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  _FakeRpc(this.payload);

  final Object? payload;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) =>
      Future.value(payload).then(onValue, onError: onError);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('updateStock writes the stock column against the variant id', () async {
    final chain = _FakeRowsChain(const []);
    final builder = _FakeQueryBuilder(chain);
    final client = _MockClient();
    when(() => client.from('product_variants')).thenAnswer((_) => builder);

    final result =
        await SupabaseAdminCatalog(client: client).updateStock('v-1', 7);

    expect(result, isA<Success<void>>());
    expect(builder.updates, [
      {'stock': 7}
    ]);
    expect(chain.calls, ['eq:id:v-1']);
  });

  test('getAllProducts applies the bounded name-ordered range page', () async {
    final chain = _FakeRowsChain(const [
      {
        'id': 'p-1',
        'name': 'Royal Emerald Silk',
        'slug': 'royal-emerald-silk',
        'category_id': 'c-1',
        'base_price': 189000,
        'is_active': true,
        'categories': {'name': 'Silk'},
      },
    ]);
    final builder = _FakeQueryBuilder(chain);
    final client = _MockClient();
    when(() => client.from('products')).thenAnswer((_) => builder);

    final result = await SupabaseAdminCatalog(client: client).getAllProducts();

    final products =
        result.when(success: (value) => value, failure: (error) => null);
    expect(products, hasLength(1));
    expect(products!.single.name, 'Royal Emerald Silk');
    expect(chain.calls, ['order:name', 'limit:100', 'range:0-99']);
    expect(builder.selects.single, contains('base_price'));
  });

  test('getProductById returns the single row, or null when it is missing',
      () async {
    final row = <String, dynamic>{
      'id': 'p-1',
      'name': 'Silk',
      'base_price': 1000,
    };
    final foundChain = _FakeRowsChain([row]);
    final missingChain = _FakeRowsChain(const []);
    final client = _MockClient();

    final foundBuilder = _FakeQueryBuilder(foundChain);
    when(() => client.from('products')).thenAnswer((_) => foundBuilder);
    final found =
        await SupabaseAdminCatalog(client: client).getProductById('p-1');
    expect(
      found.when(success: (value) => value?.id, failure: (_) => 'failed'),
      'p-1',
    );
    expect(foundChain.calls, ['eq:id:p-1', 'limit:1']);

    final missingBuilder = _FakeQueryBuilder(missingChain);
    when(() => client.from('products')).thenAnswer((_) => missingBuilder);
    final missing =
        await SupabaseAdminCatalog(client: client).getProductById('missing');
    expect(
      missing.when(success: (value) => value, failure: (_) => Object()),
      isNull,
    );
  });

  test('getAllCategories reads the sort-ordered category rows', () async {
    final chain = _FakeRowsChain(const [
      {'id': 'c-1', 'name': 'Silk', 'is_active': true},
      {'name': 'id-less row is skipped'},
    ]);
    final builder = _FakeQueryBuilder(chain);
    final client = _MockClient();
    when(() => client.from('categories')).thenAnswer((_) => builder);

    final result =
        await SupabaseAdminCatalog(client: client).getAllCategories();

    final categories =
        result.when(success: (value) => value, failure: (error) => null);
    expect(categories, hasLength(1));
    expect(categories!.single.name, 'Silk');
    expect(builder.selects.single, 'id, name, is_active');
    expect(chain.calls, ['order:sort_order']);
  });

  test('adminUpsertProduct maps an id-less RPC reply to the save failure',
      () async {
    final client = _MockClient();
    when(() => client.rpc('admin_upsert_product', params: any(named: 'params')))
        .thenAnswer((_) => _FakeRpc(''));

    final result =
        await SupabaseAdminCatalog(client: client).adminUpsertProduct(
      name: 'Silk',
      slug: 'silk',
      categoryId: 'c-1',
      basePrice: const Money.egp(100),
      isActive: true,
    );

    final failure =
        result.when(success: (_) => null, failure: (error) => error);
    expect(failure, isNotNull);
    expect(failure!.code, kAdminProductSaveFailed);
  });

  test('adminSetProductImages sends the product id and path list over RPC',
      () async {
    final client = _MockClient();
    when(() => client.rpc('admin_set_product_images',
        params: any(named: 'params'))).thenAnswer((_) => _FakeRpc(null));

    final result = await SupabaseAdminCatalog(client: client)
        .adminSetProductImages('p-1', ['a.jpg', 'b.jpg']);

    expect(result, isA<Success<void>>());
    verify(() => client.rpc('admin_set_product_images', params: {
          'p_product_id': 'p-1',
          'p_paths': ['a.jpg', 'b.jpg'],
        })).called(1);
  });

  test('getVariants reads explicit columns filtered by product id', () async {
    final chain = _FakeRowsChain(const [
      {
        'id': 'v-1',
        'size': 'M',
        'color': 'Navy',
        'stock': 4,
        'price_override': 12575,
      },
      {'size': 'id-less row is skipped'},
    ]);
    final builder = _FakeQueryBuilder(chain);
    final client = _MockClient();
    when(() => client.from('product_variants')).thenAnswer((_) => builder);

    final result =
        await SupabaseAdminCatalog(client: client).getVariants('p-1');

    final variants =
        result.when(success: (value) => value, failure: (error) => null);
    expect(variants, hasLength(1));
    expect(variants!.single.size, 'M');
    expect(builder.selects.single, 'id, size, color, stock, price_override');
    expect(chain.calls, ['eq:product_id:p-1', 'order:size']);
  });

  test('getProductImagePaths reads sort-ordered storage paths', () async {
    final chain = _FakeRowsChain(const [
      {'storage_path': 'product-images/p-1/a.jpg'},
      {'storage_path': '   '},
      {'storage_path': 42},
    ]);
    final builder = _FakeQueryBuilder(chain);
    final client = _MockClient();
    when(() => client.from('product_images')).thenAnswer((_) => builder);

    final result =
        await SupabaseAdminCatalog(client: client).getProductImagePaths('p-1');

    final paths =
        result.when(success: (value) => value, failure: (error) => null);
    expect(paths, ['product-images/p-1/a.jpg']);
    expect(builder.selects.single, 'storage_path');
    expect(chain.calls, ['eq:product_id:p-1', 'order:sort_order']);
  });
}
