import 'dart:async';

import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Filter-builder fake that records the applied limit. Mirrors the
/// chain (`select → eq → order → limit`) used by the repository.
class FakeOrdersFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  FakeOrdersFilterBuilder(this._value);
  final PostgrestList _value;

  /// Every count passed to [limit], in call order.
  final List<int> appliedLimits = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestFilterBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) {
    appliedLimits.add(count);
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<PostgrestList> catchError(Function onError,
      {bool Function(Object error)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }

  @override
  Future<PostgrestList> whenComplete(FutureOr<void> Function() action) {
    return Future.value(_value).whenComplete(action);
  }
}

class FakeOrdersQueryBuilder extends Fake implements SupabaseQueryBuilder {
  FakeOrdersQueryBuilder(this._builder);

  final FakeOrdersFilterBuilder _builder;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _builder;
}

Map<String, dynamic> _orderRow() => {
      'id': 'ord-1',
      'status': 'placed',
      'subtotal': 129000,
      'shipping': 7500,
      'total': 136500,
      'payment_method': 'cod',
      'address_snapshot': null,
      'placed_at': '2026-09-01T00:00:00Z',
      'order_items': [],
    };

void main() {
  group('SupabaseOrdersRepository — history bound (audit P4)', () {
    late MockSupabaseClient client;
    late MockGoTrueClient auth;
    late MockUser user;

    setUp(() {
      client = MockSupabaseClient();
      auth = MockGoTrueClient();
      user = MockUser();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.id).thenReturn('u1');
    });

    test('readOrders bounds history with limit(50)', () async {
      final filter = FakeOrdersFilterBuilder([_orderRow()]);
      when(() => client.from('orders'))
          .thenAnswer((_) => FakeOrdersQueryBuilder(filter));

      final repo = SupabaseOrdersRepository(client: client);
      final result = await repo.readOrders();

      expect(filter.appliedLimits, [SupabaseOrdersRepository.historyLimit]);
      expect(result, isA<Success<List<Order>>>());
      final orders = (result as Success<List<Order>>).value;
      expect(orders, hasLength(1));
      expect(orders.first.id, 'ord-1');
    });

    test('skips malformed order rows instead of failing the load (audit P2)',
        () async {
      final good = _orderRow();
      final badId = {..._orderRow()}..['id'] = '';
      final badMoney = {..._orderRow()}
        ..['id'] = 'ord-3'
        ..['subtotal'] = 'free';
      final badDate = {..._orderRow()}
        ..['id'] = 'ord-4'
        ..['placed_at'] = 'not-a-date';
      final filter = FakeOrdersFilterBuilder([good, badId, badMoney, badDate]);
      when(() => client.from('orders'))
          .thenAnswer((_) => FakeOrdersQueryBuilder(filter));

      final repo = SupabaseOrdersRepository(client: client);
      final result = await repo.readOrders();

      expect(result, isA<Success<List<Order>>>());
      final orders = (result as Success<List<Order>>).value;
      // id-less rows are skipped; mistyped money/timestamps degrade to the
      // entity default but keep the row.
      expect(orders.map((o) => o.id), ['ord-1', 'ord-3', 'ord-4']);
      expect(orders[1].subtotal.minorUnits, 0);
      expect(orders[2].placedAt, isA<DateTime>());
    });
  });
}
