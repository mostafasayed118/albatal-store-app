import 'dart:async';

import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/data/checkout_service.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import '../../../fixtures/products_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _ValueBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  _ValueBuilder(this._value);
  final dynamic _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue,
      {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(Function onError,
      {bool Function(Object error)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }

  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) {
    return Future.value(_value).whenComplete(action);
  }

  @override
  Future<dynamic> timeout(Duration timeLimit,
      {FutureOr<dynamic> Function()? onTimeout}) {
    return Future<dynamic>.value(_value)
        .timeout(timeLimit, onTimeout: onTimeout);
  }
}

/// Never completes on its own — the RPC `.timeout()` is the only thing
/// that resolves it. Proves a hung request surfaces Failure instead of
/// stalling checkout forever.
class _HangingBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue,
      {Function? onError}) {
    return Completer<R>().future;
  }

  @override
  Future<dynamic> timeout(Duration timeLimit,
      {FutureOr<dynamic> Function()? onTimeout}) {
    return Completer<dynamic>().future.timeout(timeLimit, onTimeout: onTimeout);
  }
}

Map<String, dynamic> _okResponse() => {
      'order_id': 'server-ord-001',
      'subtotal': 129000,
      'shipping': 7500,
      'total': 136500,
      'expires_at': '2026-09-04T00:00:00Z',
      'status': 'pending',
    };

List<CartItem> _items() => [
      CartItem(
          product: products.first, color: 'Emerald', length: '2m', quantity: 1),
    ];

void _stubRpc(_MockSupabaseClient client, dynamic value) {
  when(() => client.rpc('create_checkout_order', params: any(named: 'params')))
      .thenAnswer((_) => _ValueBuilder(value));
}

Future<Result<PendingOrder>> _place(_MockSupabaseClient client,
    {Duration? rpcTimeout}) {
  final service = CheckoutService(
      client: client, rpcTimeout: rpcTimeout ?? const Duration(seconds: 15));
  return service.placeOrder(
    items: _items(),
    paymentMethod: PaymentMethod.cashOnDelivery,
    addressSnapshot: const {},
  );
}

/// Regression tests for the RPC response hardening: the raw PostgREST
/// payload is untyped, so every shape violation must degrade to a
/// scrubbed Failure — never a TypeError into the cubit, never a
/// fabricated `Money(0)` flowing into payment.
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('non-map payload (list) fails closed without throwing', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, [
      {'order_id': 'x'}
    ]);

    final result = await _place(client);

    expect(result, isA<Failure>());
    expect((result as Failure).error.message, 'Checkout failed');
  });

  test('null payload fails closed without throwing', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, null);

    expect(await _place(client), isA<Failure>());
  });

  test('missing order_id fails closed (never a placeholder id)', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, _okResponse()..remove('order_id'));

    final result = await _place(client);

    expect(result, isA<Failure>());
    expect((result as Failure).error.message, 'Checkout failed');
  });

  test('empty order_id fails closed', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, _okResponse()..['order_id'] = '');

    expect(await _place(client), isA<Failure>());
  });

  test('unparseable expires_at fails closed (never a fake deadline)', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, _okResponse()..['expires_at'] = 'not-a-date');

    expect(await _place(client), isA<Failure>());
  });

  test('missing money fails closed (never Money(0) into payment)', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, _okResponse()..remove('total'));

    final result = await _place(client);

    expect(result, isA<Failure>());
    expect((result as Failure).error.message, 'Checkout failed');
  });

  test('integer-valued doubles coerce to minor units', () async {
    final client = _MockSupabaseClient();
    _stubRpc(
        client,
        _okResponse()
          ..['subtotal'] = 129000.0
          ..['shipping'] = 7500.0
          ..['total'] = 136500.0);

    final result = await _place(client);

    expect(result, isA<Success<PendingOrder>>());
    expect((result as Success<PendingOrder>).value.total.minorUnits, 136500);
  });

  test('non-string-keyed map is normalized, not rejected', () async {
    final client = _MockSupabaseClient();
    _stubRpc(client, Map<dynamic, dynamic>.from(_okResponse()));

    expect(await _place(client), isA<Success<PendingOrder>>());
  });

  test('hung RPC times out to a scrubbed Failure', () async {
    final client = _MockSupabaseClient();
    when(() =>
            client.rpc('create_checkout_order', params: any(named: 'params')))
        .thenAnswer((_) => _HangingBuilder());

    final result =
        await _place(client, rpcTimeout: const Duration(milliseconds: 50));

    expect(result, isA<Failure>());
    expect((result as Failure).error.message, 'Checkout failed');
  }, timeout: const Timeout(Duration(seconds: 10)));
}
