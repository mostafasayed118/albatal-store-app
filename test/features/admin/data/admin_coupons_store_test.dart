import 'dart:async';

import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/data/admin_coupons_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Records the server filters/ordering and answers the awaited chain.
class _FakeFilter extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilter({
    this.rows = const [],
    this.row = const {},
    this.error,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> row;
  final Object? error;

  final List<(String, Object)> eqs = [];
  final List<(String, bool)> orders = [];
  final List<String> selects = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    eqs.add((column, value));
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    orders.add((column, ascending));
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    selects.add(columns);
    return this;
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() =>
      _FakeSingle(row, error);

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

class _FakeSingle extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>> {
  _FakeSingle(this.row, this.error);

  final Map<String, dynamic> row;
  final Object? error;

  @override
  Future<R> then<R>(FutureOr<R> Function(Map<String, dynamic> value) onValue,
      {Function? onError}) {
    final error = this.error;
    final future = error != null
        ? Future<Map<String, dynamic>>.error(error)
        : Future.value(row);
    return future.then(onValue, onError: onError);
  }
}

T _value<T>(Result<T> result) => switch (result) {
      Success<T>(:final value) => value,
      Failure<T>() => fail('expected Success, got ${result.error.message}'),
    };

String _errorCode<T>(Result<T> result) => switch (result) {
      Success<T>() => fail('expected Failure'),
      Failure<T>(:final error) => error.code!,
    };

void main() {
  late _MockClient client;
  late _MockQueryBuilder builder;
  late SupabaseAdminCoupons store;

  setUp(() {
    client = _MockClient();
    builder = _MockQueryBuilder();
    when(() => client.from('coupons')).thenAnswer((_) => builder);
    store = SupabaseAdminCoupons(client: client);
  });

  group('fetchCoupons', () {
    test('maps rows, uppercases codes, skips id-less rows, newest first',
        () async {
      final filter = _FakeFilter(rows: [
        {
          'id': 'c2',
          'code': 'eid25',
          'discount_minor': 1000,
          'description': 'Eid',
          'active': true,
        },
        {
          'id': 'c1',
          'code': 'save',
          'discount_minor': 250,
          'active': false,
        },
        {'code': 'NOID', 'discount_minor': 100},
      ]);
      when(() =>
              builder.select('id, code, discount_minor, description, active'))
          .thenAnswer((_) => filter);

      final coupons = _value(await store.fetchCoupons());

      expect(coupons.map((c) => c.code), ['EID25', 'SAVE']);
      expect(coupons.first.discountMinor, 1000);
      expect(coupons.first.description, 'Eid');
      expect(coupons.first.active, isTrue);
      expect(coupons.last.description, isNull);
      expect(coupons.last.active, isFalse);
      expect(filter.orders, [('created_at', false)],
          reason: 'newest first is a server-side order, not a client sort');
    });

    test('read failure maps to the coupon load code', () async {
      final filter = _FakeFilter(
        error: const PostgrestException(
            message: 'row-level security', code: '42501'),
      );
      when(() =>
              builder.select('id, code, discount_minor, description, active'))
          .thenAnswer((_) => filter);

      expect(_errorCode(await store.fetchCoupons()), kAdminCouponsLoadFailed);
    });
  });

  group('createCoupon', () {
    test('trims/uppercases the code and returns the selected row', () async {
      final filter = _FakeFilter(row: {
        'id': 'c9',
        'code': 'SAVE10',
        'discount_minor': 2500,
        'description': 'Promo',
        'active': true,
      });
      when(() => builder.upsert(any())).thenAnswer((_) => filter);

      final coupon = _value(await store.createCoupon(
        code: ' save10 ',
        discountMinor: 2500,
        description: 'Promo',
      ));

      final payload = verify(() => builder.upsert(captureAny())).captured.single
          as Map<Object?, Object?>;
      expect(payload['code'], 'SAVE10');
      expect(payload['discount_minor'], 2500);
      expect(payload['description'], 'Promo');
      expect(filter.selects.single,
          'id, code, discount_minor, description, active');
      expect(coupon.id, 'c9');
      expect(coupon.code, 'SAVE10');
      expect(coupon.active, isTrue);
    });

    test('omits a null/empty description from the upsert payload', () async {
      final filter = _FakeFilter(row: {
        'id': 'c9',
        'code': 'SAVE10',
        'discount_minor': 2500,
        'active': true,
      });
      when(() => builder.upsert(any())).thenAnswer((_) => filter);

      await store.createCoupon(code: 'SAVE10', discountMinor: 2500);
      await store.createCoupon(
          code: 'SAVE10', discountMinor: 2500, description: '');

      final payloads = verify(() => builder.upsert(captureAny())).captured;
      for (final payload in payloads.cast<Map<Object?, Object?>>()) {
        expect(payload.containsKey('description'), isFalse);
      }
    });

    test('a row without an id fails instead of returning a ghost coupon',
        () async {
      final filter = _FakeFilter(row: {'code': 'SAVE10'});
      when(() => builder.upsert(any())).thenAnswer((_) => filter);

      expect(
        _errorCode(
            await store.createCoupon(code: 'SAVE10', discountMinor: 2500)),
        kAdminCouponCreateFailed,
      );
    });

    test('server rejection keeps the create machine code', () async {
      final filter =
          _FakeFilter(error: const PostgrestException(message: 'duplicate'));
      when(() => builder.upsert(any())).thenAnswer((_) => filter);

      expect(
        _errorCode(
            await store.createCoupon(code: 'SAVE10', discountMinor: 2500)),
        kAdminCouponCreateFailed,
      );
    });
  });

  group('setCouponActive', () {
    test('updates only the addressed row and reports success', () async {
      final filter = _FakeFilter();
      when(() => builder.update(any())).thenAnswer((_) => filter);

      final result = await store.setCouponActive('c1', false);

      expect(result, isA<Success<void>>());
      verify(() => builder.update({'active': false})).called(1);
      expect(filter.eqs, [('id', 'c1')]);
    });

    test('write failure maps to the coupon update code', () async {
      final filter = _FakeFilter(error: Exception('permission denied'));
      when(() => builder.update(any())).thenAnswer((_) => filter);

      expect(_errorCode(await store.setCouponActive('c1', true)),
          kAdminCouponUpdateFailed);
    });
  });
}
