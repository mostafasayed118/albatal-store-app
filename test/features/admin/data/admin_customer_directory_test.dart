import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/supabase_admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression guards for the admin data layer.
///
/// The customer directory previously requested `email` from `profiles`, a
/// column that does not exist (the address lives in `auth.users`, which
/// PostgREST does not expose). PostgREST answered 42703, the repository
/// mapped it to `Failure`, and the Customers screen could never list anyone.
/// It stayed invisible because every existing test drove the page through a
/// STUB repository — the real `SupabaseAdminRepository` had no test at all.
///
/// `getOrderDetails` is covered for the same reason: its embedded
/// `profiles(...)` join is subject to the viewer's RLS, so it now goes through
/// the admin-checked `get_order_details` RPC instead.

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Awaitable terminal builder (the repository `await`s the chain).
class FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  FakeTransformBuilder(this._value);

  final T _value;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      this;

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      Future.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future.value(_value).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_value).whenComplete(action);

  @override
  Stream<T> asStream() => Future.value(_value).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future.value(_value).timeout(timeLimit, onTimeout: onTimeout);
}

/// `select()` returns a `PostgrestFilterBuilder`, which is NOT a subtype of
/// the transform builder, so it needs its own fake that hands back one.
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeFilterBuilder(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) =>
      FakeTransformBuilder<T>(_rows as T);

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      FakeTransformBuilder<T>(_rows as T);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      Future.value(_rows as T).then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future.value(_rows as T).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_rows as T).whenComplete(action);

  @override
  Stream<T> asStream() => Future.value(_rows as T).asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future.value(_rows as T).timeout(timeLimit, onTimeout: onTimeout);
}

/// `rpc()` hands back a `PostgrestFilterBuilder` carrying a single decoded
/// JSON payload (not a row list), so the customer-directory fakes above need
/// an Object?-shaped sibling for the `get_order_details` tests.
class _FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<Object?> {
  _FakeRpcBuilder(this._payload);

  final Object? _payload;

  @override
  Future<R> then<R>(FutureOr<R> Function(Object? value) onValue,
          {Function? onError}) =>
      Future.value(_payload).then(onValue, onError: onError);

  @override
  Future<Object?> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future.value(_payload).catchError(onError, test: test);

  @override
  Future<Object?> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_payload).whenComplete(action);

  @override
  Stream<Object?> asStream() => Future.value(_payload).asStream();
}

void main() {
  // ─── fetchCustomers ─────────────────────────────────────
  //
  // Regression guard (doc comment above): the directory once requested the
  // nonexistent `profiles.email` column; PostgREST answered 42703 and the
  // whole screen degraded to a permanent error. The stub below matches the
  // exact column list the repository MUST request — any drift (including
  // re-adding `email`) misses the stub and fails the test.
  test('fetchCustomers selects only real profiles columns and maps rows',
      () async {
    final client = MockSupabaseClient();
    final builder = MockSupabaseQueryBuilder();
    when(() => client.from('profiles')).thenAnswer((_) => builder);
    when(() => builder.select('id, full_name, phone, membership_tier'))
        .thenAnswer((_) => FakeFilterBuilder<PostgrestList>([
      {
        'id': 'c1',
        'full_name': 'Layla',
        'phone': '01000000000',
        'membership_tier': 'premium',
      },
      {'id': 'c2', 'full_name': 'Omar'},
    ]));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.fetchCustomers();

    verify(() => builder.select('id, full_name, phone, membership_tier'))
        .called(1);
    final customers = result.when(success: (v) => v, failure: (_) => null);
    expect(customers, isNotNull);
    expect(customers!.length, 2);
    expect(customers[0].id, 'c1');
    expect(customers[0].name, 'Layla');
    expect(customers[0].phone, '01000000000');
    expect(customers[0].contact, '01000000000'); // no email column → phone
    expect(customers[0].tier, 'premium');
    expect(customers[0].isBlocked, isFalse); // §14 read-only directory
    expect(customers[1].tier, 'standard'); // tolerant default
    expect(customers[1].phone, '');
  });

  test('fetchCustomers maps a PostgREST failure to Failure (never throws)',
      () async {
    final client = MockSupabaseClient();
    final builder = MockSupabaseQueryBuilder();
    when(() => client.from('profiles')).thenAnswer((_) => builder);
    when(() => builder.select('id, full_name, phone, membership_tier'))
        .thenThrow(Exception('42703 column profiles.email does not exist'));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.fetchCustomers();

    expect(result, isA<Failure<List<AdminCustomer>>>());
  });

  // ─── getOrderDetails ────────────────────────────────────
  //
  // Regression guard (doc comment above): the embedded profiles(...) join
  // was subject to the VIEWER's RLS and returned a null profile for every
  // other user's order. The detail path must go through the admin-checked
  // `get_order_details` RPC instead.
  test('getOrderDetails resolves through the admin-checked RPC', () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('get_order_details',
        params: {'p_order_id': 'o1'})).thenAnswer(
      (_) => _FakeRpcBuilder({
        'order': {
          'id': 'o1',
          'status': 'placed',
          'total': 129000,
          'placed_at': '2026-09-01T10:00:00Z',
          'payment_method': 'card',
        },
        'items': [
          {
            'product_name': 'Silk',
            'size': '4m',
            'color': 'Navy',
            'quantity': 1,
            'unit_price': 129000,
          },
        ],
        'customer': {
          'id': 'c1',
          'full_name': 'Layla',
          'membership_tier': 'premium',
        },
      }),
    );
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.getOrderDetails('o1');

    verify(() => client.rpc('get_order_details', params: {'p_order_id': 'o1'}))
        .called(1);
    final order = result.when(success: (v) => v, failure: (_) => null);
    expect(order, isNotNull);
    expect(order!.id, 'o1');
    expect(order.status, AdminOrderStatus.placed);
    expect(order.total, const Money(129000));
    expect(order.customerId, 'c1');
    expect(order.customerName, 'Layla');
    expect(order.customerTier, 'premium');
    expect(order.items.length, 1);
    expect(order.itemCount, 1);
    expect(order.items.first.productName, 'Silk');
  });

  test('getOrderDetails degrades a missing order to Success(null)', () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('get_order_details',
        params: {'p_order_id': 'missing'}))
        .thenAnswer((_) => _FakeRpcBuilder(<String, dynamic>{}));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.getOrderDetails('missing');

    final order = result.when(success: (v) => v, failure: (_) => throw 'fail');
    expect(order, isNull);
  });

  test('getOrderDetails maps an RPC failure to Failure (never throws)',
      () async {
    final client = MockSupabaseClient();
    when(() => client.rpc('get_order_details',
        params: {'p_order_id': 'o1'})).thenThrow(Exception('permission'));
    final repo = SupabaseAdminRepository(client: client);

    final result = await repo.getOrderDetails('o1');

    expect(result, isA<Failure<AdminOrder?>>());
  });
}
