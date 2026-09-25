import 'dart:async';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _OrdersFrom extends Fake implements SupabaseQueryBuilder {
  _OrdersFrom(this._filter, this.selects);

  final _OrdersFilter _filter;
  final List<String> selects;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    selects.add(columns);
    return _filter;
  }
}

class _OrdersFilter extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _OrdersFilter(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      _OrdersTransform(_rows);
}

class _OrdersTransform extends Fake
    implements PostgrestTransformBuilder<PostgrestList> {
  _OrdersTransform(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) =>
      this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      Future.value(_rows).then(onValue, onError: onError);
}

void main() {
  test('order list selects payment_id and maps it as fulfillment tracking',
      () async {
    final client = _MockSupabaseClient();
    final selects = <String>[];
    final rows = <Map<String, dynamic>>[
      {
        'id': 'order-1',
        'status': 'shipped',
        'total': 129000,
        'payment_method': 'cod',
        'payment_id': 'TRACK-42',
        'profiles': {'full_name': 'Sara Ali'},
        'order_items': [
          {'id': 'item-1'},
        ],
      },
    ];
    when(() => client.from('orders'))
        .thenAnswer((_) => _OrdersFrom(_OrdersFilter(rows), selects));

    final result = await SupabaseAdminRepository(client: client).getAllOrders();

    expect(result, isA<Success<List<AdminOrder>>>());
    final order = (result as Success<List<AdminOrder>>).value.single;
    expect(order.trackingNumber, 'TRACK-42');
    expect(selects.single, contains('payment_id'));
    expect(selects.single, isNot(contains('tracking_number')));
  });
}
