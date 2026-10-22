import 'dart:async';

import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.chain);

  final _FakeChain chain;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) => chain;
}

class _FakeChain extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  _FakeChain(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

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
      Future<PostgrestList>.value(rows).then(onValue, onError: onError);
}

Map<String, dynamic> _orderRow({
  String id = 'ord-1',
  String status = 'placed',
  Object? items = const <Map<String, dynamic>>[],
  Object? address,
}) =>
    {
      'id': id,
      'status': status,
      'subtotal': 129000,
      'shipping': 7500,
      'total': 136500,
      'payment_method': 'cod',
      'address_snapshot': address,
      'placed_at': '2026-09-01T00:00:00Z',
      'order_items': items,
    };

Map<String, dynamic> _itemRow({
  String productId = 'p1',
  String name = 'Royal Silk',
  String color = 'Emerald',
  String size = '2m',
  int unitPrice = 129000,
  int quantity = 2,
}) =>
    {
      'product_id': productId,
      'product_name': name,
      'color': color,
      'size': size,
      'unit_price': unitPrice,
      'quantity': quantity,
    };

void main() {
  late _MockClient client;
  late _MockAuth auth;
  late _MockUser user;

  setUp(() {
    client = _MockClient();
    auth = _MockAuth();
    user = _MockUser();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn('u1');
  });

  SupabaseOrdersRepository repo() => SupabaseOrdersRepository(client: client);

  group('SupabaseOrdersRepository.readOrders failures', () {
    test('a signed-out caller gets the not-authenticated code', () async {
      when(() => auth.currentUser).thenReturn(null);

      final result = await repo().readOrders();

      expect(result, isA<Failure<List<Order>>>());
      expect((result as Failure).error.code, kFailureNotAuthenticated);
      verifyNever(() => client.from(any()));
    });

    test('a transport failure maps to the load code', () async {
      when(() => client.from('orders')).thenThrow(Exception('offline'));

      final result = await repo().readOrders();

      expect(result, isA<Failure<List<Order>>>());
      expect((result as Failure).error.code, kFailureLoad);
    });
  });

  group('SupabaseOrdersRepository.readOrders decoding', () {
    test('maps items, the address snapshot, and a known status', () async {
      final chain = _FakeChain([
        _orderRow(
          items: [
            _itemRow(),
            _itemRow(productId: '', name: 'Skipped'),
          ],
          address: {
            'id': 'a1',
            'recipient': 'Nour',
            'line': '12 Nile Street',
            'city': 'Cairo',
            'country': 'EG',
            'phone': '01000000000',
          },
        ),
      ]);
      when(() => client.from('orders'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().readOrders();

      expect(result, isA<Success<List<Order>>>());
      final order = (result as Success<List<Order>>).value.single;
      expect(order.status, OrderStatus.placed);
      expect(order.items, hasLength(1));
      final item = order.items.single;
      expect(item.product.id, 'p1');
      expect(item.product.name, 'Royal Silk');
      expect(item.product.price.minorUnits, 129000);
      expect(item.color, 'Emerald');
      expect(item.length, '2m');
      expect(item.quantity, 2);
      expect(order.address?.city, 'Cairo');
      expect(order.address?.phone, '01000000000');
    });

    test('a non-list order_items value decodes to an empty item list',
        () async {
      final chain = _FakeChain([_orderRow(items: 'not-a-list')]);
      when(() => client.from('orders'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().readOrders();

      final order = (result as Success<List<Order>>).value.single;
      expect(order.items, isEmpty);
    });

    test('an unknown status degrades to placed', () async {
      final chain = _FakeChain([_orderRow(status: 'teleported')]);
      when(() => client.from('orders'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().readOrders();

      final order = (result as Success<List<Order>>).value.single;
      expect(order.status, OrderStatus.placed);
    });

    test('a non-map address snapshot leaves the address null', () async {
      final chain = _FakeChain([_orderRow(address: 'not-a-map')]);
      when(() => client.from('orders'))
          .thenAnswer((_) => _FakeQueryBuilder(chain));

      final result = await repo().readOrders();

      final order = (result as Success<List<Order>>).value.single;
      expect(order.address, isNull);
    });
  });
}
