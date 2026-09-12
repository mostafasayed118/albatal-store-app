import 'dart:async';

import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/data/checkout_service.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../fixtures/products_data.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._value);
  final T _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future.value(_value).catchError(onError, test: test);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future.value(_value).whenComplete(action);
  }
}

Map<String, dynamic> _rpcResponse() => {
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

/// Guards the client→server payment-method contract: the strings sent
/// must be exactly what the server gates on, or card initiation is
/// rejected with "Unsupported payment method" (035 / paymob-initiate)
/// and COD confirmation with "payment_not_cod" (018/022/026).
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('sends canonical paymob_card for card checkout', () async {
    final client = MockSupabaseClient();
    when(() =>
            client.rpc('create_checkout_order', params: any(named: 'params')))
        .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(_rpcResponse()));

    final service = CheckoutService(client: client);
    final result = await service.placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.paymobCard,
      addressSnapshot: const {},
    );

    expect(result, isA<Success<PendingOrder>>());
    final captured = verify(() => client.rpc('create_checkout_order',
        params: captureAny(named: 'params'))).captured;
    expect((captured.single as Map)['p_payment_method'], 'paymob_card');
  });

  test('sends canonical cod for cash-on-delivery checkout', () async {
    final client = MockSupabaseClient();
    when(() =>
            client.rpc('create_checkout_order', params: any(named: 'params')))
        .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(_rpcResponse()));

    final service = CheckoutService(client: client);
    final result = await service.placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.cashOnDelivery,
      addressSnapshot: const {},
    );

    expect(result, isA<Success<PendingOrder>>());
    final captured = verify(() => client.rpc('create_checkout_order',
        params: captureAny(named: 'params'))).captured;
    expect((captured.single as Map)['p_payment_method'], 'cod');
  });

  test('accepts JSON-decoded double money fields from the RPC', () async {
    final client = MockSupabaseClient();
    final response = {..._rpcResponse()};
    response['subtotal'] = 129000.0;
    response['total'] = 136500.0;
    when(() =>
            client.rpc('create_checkout_order', params: any(named: 'params')))
        .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(response));

    final service = CheckoutService(client: client);
    final result = await service.placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.paymobCard,
      addressSnapshot: const {},
    );

    expect(result, isA<Success<PendingOrder>>());
    expect((result as Success<PendingOrder>).value.total.minorUnits, 136500);
  });

  test('fails closed on a malformed RPC payload instead of throwing', () async {
    Future<Result<PendingOrder>> place(Map<String, dynamic> payload) async {
      final client = MockSupabaseClient();
      when(() =>
              client.rpc('create_checkout_order', params: any(named: 'params')))
          .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(payload));
      final service = CheckoutService(client: client);
      return service.placeOrder(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        addressSnapshot: const {},
      );
    }

    // Missing order id — payment hand-off would be corrupted.
    expect(
      await place({..._rpcResponse()}..remove('order_id')),
      isA<Failure<PendingOrder>>(),
    );
    // Money fields are not integers.
    expect(
      await place({..._rpcResponse()}..['subtotal'] = 'free'),
      isA<Failure<PendingOrder>>(),
    );
    // Unparseable expiry.
    expect(
      await place({..._rpcResponse()}..['expires_at'] = 'not-a-date'),
      isA<Failure<PendingOrder>>(),
    );
  });
}
