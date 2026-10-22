import 'dart:async';

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/data/checkout_service.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  _FakeRpc(this.payload);

  final Object? payload;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) =>
      Future<dynamic>.value(payload).then(onValue, onError: onError);
}

const _address = Address(
  id: 'a1',
  recipient: 'Nour',
  line: '12 Nile Street',
  city: 'Cairo',
  country: 'EG',
  phone: '01000000000',
);

List<CartItem> _items() => [
      const CartItem(
        product: Product(
          id: 'p1',
          name: 'Royal Silk',
          category: 'Silk',
          price: Money(129000),
          imageColor: 0xFF176B57,
        ),
        color: 'Emerald',
        length: '2m',
        quantity: 1,
      ),
    ];

Map<String, dynamic> _response() => {
      'order_id': 'ord-1',
      'subtotal': 129000,
      'shipping': 7500,
      'total': 136500,
      'expires_at': '2026-09-04T00:00:00Z',
      'status': 'placed',
      'idempotent': true,
    };

void main() {
  late _MockClient client;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockClient();
  });

  CheckoutService service() => CheckoutService(client: client);

  Map<String, dynamic> captureParams() {
    final captured = verify(() => client.rpc('create_checkout_order',
        params: captureAny(named: 'params'))).captured;
    return captured.single as Map<String, dynamic>;
  }

  void stubResponse(Object? payload) {
    when(() =>
            client.rpc('create_checkout_order', params: any(named: 'params')))
        .thenAnswer((_) => _FakeRpc(payload));
  }

  test('encodes the address snapshot and optional coupon/idempotency keys',
      () async {
    stubResponse(_response());

    final result = await service().placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.cashOnDelivery,
      address: _address,
      couponCode: 'SAVE10',
      idempotencyKey: 'idem-1',
    );

    expect(result, isA<Success<PendingOrder>>());
    final params = captureParams();
    expect(params['p_payment_method'], 'cod');
    expect(params['p_coupon_code'], 'SAVE10');
    expect(params['p_idempotency_key'], 'idem-1');
    final snapshot = params['p_address'] as Map<String, dynamic>;
    expect(snapshot['recipient'], 'Nour');
    expect(snapshot['city'], 'Cairo');
    expect(snapshot['phone'], '01000000000');
    expect(snapshot.containsKey('isDefault'), isFalse);
  });

  test('omits coupon and idempotency keys when absent', () async {
    stubResponse(_response());

    await service().placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.paymobCard,
      address: null,
    );

    final params = captureParams();
    expect(params['p_address'], isEmpty);
    expect(params.containsKey('p_coupon_code'), isFalse);
    expect(params.containsKey('p_idempotency_key'), isFalse);
  });

  test('decodes the server status and idempotent flag', () async {
    stubResponse(_response());

    final result = await service().placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.paymobCard,
      address: null,
    );

    final pending = (result as Success<PendingOrder>).value;
    expect(pending.status, OrderStatus.placed);
    expect(pending.isIdempotentRetry, isTrue);
    expect(pending.subtotal.minorUnits, 129000);
    expect(pending.shipping.minorUnits, 7500);
    expect(pending.total.minorUnits, 136500);
  });

  test('a malformed RPC payload fails closed with the checkout code', () async {
    stubResponse({
      'order_id': 'ord-1',
      'subtotal': 1,
      'shipping': 1,
      'total': 1,
      // expires_at missing
    });

    final result = await service().placeOrder(
      items: _items(),
      paymentMethod: PaymentMethod.paymobCard,
      address: null,
    );

    expect(result, isA<Failure<PendingOrder>>());
    expect((result as Failure).error.code, kCheckoutFailedCode);
  });

  group('CheckoutService Postgrest mapping', () {
    Future<Result<PendingOrder>> placeThrowing(PostgrestException error) {
      when(() =>
              client.rpc('create_checkout_order', params: any(named: 'params')))
          .thenThrow(error);
      return service().placeOrder(
        items: _items(),
        paymentMethod: PaymentMethod.paymobCard,
        address: null,
      );
    }

    test('a duplicate code collapses to the generic message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'whatever', code: '23505'));

      expect((result as Failure).error.message, 'Checkout failed');
      expect((result as Failure).error.code, kCheckoutFailedCode);
    });

    test('duplicate wording collapses to the generic message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'duplicate key value'));

      expect((result as Failure).error.message, 'Checkout failed');
    });

    test('already wording collapses to the generic message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'order already exists'));

      expect((result as Failure).error.message, 'Checkout failed');
    });

    test('insufficient stock gets the stock message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'Insufficient stock for p1'));

      expect((result as Failure).error.message, 'Some items are out of stock.');
      expect((result as Failure).error.code, kCheckoutFailedCode);
    });

    test('out-of-stock wording gets the stock message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'item is out of stock'));

      expect((result as Failure).error.message, 'Some items are out of stock.');
    });

    test('invalid payment method gets the payment message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'invalid payment method'));

      expect((result as Failure).error.message, 'Unsupported payment method.');
      expect((result as Failure).error.code, kCheckoutFailedCode);
    });

    test('unsupported payment gets the payment message', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'unsupported payment'));

      expect((result as Failure).error.message, 'Unsupported payment method.');
    });

    test('an unrecognized failure never leaks the server wording', () async {
      final result = await placeThrowing(
          const PostgrestException(message: 'pg: relation "secret" missing'));

      expect((result as Failure).error.message, 'Checkout failed');
      expect((result as Failure).error.code, kCheckoutFailedCode);
    });
  });
}
