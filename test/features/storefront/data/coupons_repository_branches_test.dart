import 'dart:async';

import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_coupons_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/coupon_discount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  _FakeRpc(this.payload, {this.error});

  final Object? payload;
  final Object? error;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    if (error != null) {
      return Future<dynamic>.error(error!).then(onValue, onError: onError);
    }
    return Future<dynamic>.value(payload).then(onValue, onError: onError);
  }
}

void main() {
  late _MockClient client;

  setUp(() {
    client = _MockClient();
  });

  SupabaseCouponsRepository repo() => SupabaseCouponsRepository(client: client);

  group('SupabaseCouponsRepository.validate guards', () {
    test('blank code fails invalid without touching the RPC', () async {
      for (final code in ['', '   ']) {
        final result = await repo().validate(code);
        expect((result as Failure).error.message, kCouponInvalid);
      }
      verifyNever(() => client.rpc(any(), params: any(named: 'params')));
    });
  });

  group('SupabaseCouponsRepository.validate payload mapping', () {
    test('maps the first RPC row and trims the submitted code', () async {
      final params = <String, dynamic>{};
      when(() => client.rpc('validate_coupon', params: any(named: 'params')))
          .thenAnswer((invocation) {
        params
            .addAll(invocation.namedArguments[#params] as Map<String, dynamic>);
        return _FakeRpc([
          {'code': 'save10', 'discount_minor': 5000, 'description': 'Ten off'},
          {'code': 'ignored', 'discount_minor': 1},
        ]);
      });

      final result = await repo().validate('  SAVE10  ');

      expect(result, isA<Success<CouponDiscount>>());
      final coupon = (result as Success<CouponDiscount>).value;
      expect(coupon.code, 'SAVE10');
      expect(coupon.discountMinor, 5000);
      expect(coupon.description, 'Ten off');
      expect(params['p_code'], 'SAVE10');
    });

    test('an empty RPC list fails invalid', () async {
      when(() => client.rpc('validate_coupon', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc(const []));

      final result = await repo().validate('SAVE10');

      expect((result as Failure).error.message, kCouponInvalid);
    });

    test('a non-list RPC payload fails invalid', () async {
      when(() => client.rpc('validate_coupon', params: any(named: 'params')))
          .thenAnswer(
              (_) => _FakeRpc({'code': 'SAVE10', 'discount_minor': 100}));

      final result = await repo().validate('SAVE10');

      expect((result as Failure).error.message, kCouponInvalid);
    });

    test('a list of non-maps fails invalid', () async {
      when(() => client.rpc('validate_coupon', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc([42, 'nope']));

      final result = await repo().validate('SAVE10');

      expect((result as Failure).error.message, kCouponInvalid);
    });

    test('a row with a non-positive discount fails invalid', () async {
      when(() => client.rpc('validate_coupon', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc([
                {'code': 'SAVE10', 'discount_minor': 0}
              ]));

      final result = await repo().validate('SAVE10');

      expect((result as Failure).error.message, kCouponInvalid);
    });
  });

  group('SupabaseCouponsRepository.validate failures', () {
    Future<Result<CouponDiscount>> validateThrowing(Object error) {
      when(() => client.rpc('validate_coupon', params: any(named: 'params')))
          .thenAnswer((_) => _FakeRpc(null, error: error));
      return repo().validate('SAVE10');
    }

    test('undefined function maps to unavailable', () async {
      final result = await validateThrowing(
          const PostgrestException(message: 'no such function', code: '42883'));

      expect((result as Failure).error.message, kCouponUnavailable);
    });

    test('PGRST202 maps to unavailable', () async {
      final result = await validateThrowing(
          const PostgrestException(message: 'missing', code: 'PGRST202'));

      expect((result as Failure).error.message, kCouponUnavailable);
    });

    test('schema-cache wording maps to unavailable', () async {
      final result = await validateThrowing(
          const PostgrestException(message: 'Could not find in schema cache'));

      expect((result as Failure).error.message, kCouponUnavailable);
    });

    test('an unrelated Postgrest failure maps to invalid', () async {
      final result = await validateThrowing(const PostgrestException(
          message: 'permission denied', code: '42501'));

      expect((result as Failure).error.message, kCouponInvalid);
    });

    test('a non-Exception throw is also caught and maps to invalid', () async {
      final result = await validateThrowing(StateError('decoder exploded'));

      expect((result as Failure).error.message, kCouponInvalid);
    });
  });
}
