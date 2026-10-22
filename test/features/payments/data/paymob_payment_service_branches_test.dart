import 'dart:async';
import 'dart:convert';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/data/paymob_payment_service.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

/// Awaitable `PostgrestFilterBuilder` fake. Unlike the admin helper this
/// also overrides [timeout] because the payment service appends
/// `.timeout(_rpcTimeout)` to every RPC chain.
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

  @override
  Future<Object?> timeout(Duration timeLimit,
          {FutureOr<Object?> Function()? onTimeout}) =>
      Future.value(_payload);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSupabaseClient client;
  late _MockFunctionsClient functions;
  late PaymobPaymentService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockSupabaseClient();
    functions = _MockFunctionsClient();
    when(() => client.functions).thenAnswer((_) => functions);
    service = PaymobPaymentService(client: client);
  });

  void stubInvoke(String fn, FunctionResponse response) {
    when(() => functions.invoke(fn, body: any(named: 'body')))
        .thenAnswer((_) async => response);
  }

  void stubRpc(String fn, Object? payload) {
    when(() => client.rpc<dynamic>(fn, params: any(named: 'params')))
        .thenAnswer((_) => _FakeRpcBuilder(payload));
  }

  group('initiatePayment', () {
    test('valid checkout_url returns PaymentPending', () async {
      stubInvoke(
        'paymob-initiate',
        const FunctionResponse(
          status: 200,
          data: {
            'checkout_url':
                'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=abc',
          },
        ),
      );

      final result = await service.initiatePayment(
        amount: const Money.egp(100),
        method: PaymentMethod.paymobCard,
        orderId: 'ord-1',
        customerEmail: 'customer@example.com',
      );

      expect(result, isA<PaymentPending>());
      expect(
        (result as PaymentPending).checkoutUrl,
        'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=abc',
      );

      final body = verify(() => functions.invoke('paymob-initiate',
          body: captureAny(named: 'body'))).captured.single as Map;
      expect(body['order_id'], 'ord-1');
      expect(body['amount_cents'], 10000);
      expect(body['customer_email'], 'customer@example.com');
    });

    test('non-200 response maps the server message', () async {
      stubInvoke(
        'paymob-initiate',
        const FunctionResponse(status: 400, data: {'message': 'Card declined'}),
      );

      final result = await service.initiatePayment(
        amount: const Money.egp(100),
        method: PaymentMethod.paymobCard,
        orderId: 'ord-1',
        customerEmail: 'customer@example.com',
      );

      expect(result, isA<PaymentFailed>());
      expect((result as PaymentFailed).message, 'Card declined');
      expect(result.code, isNull);
    });

    test('non-200 response with a malformed body falls back', () async {
      stubInvoke(
        'paymob-initiate',
        const FunctionResponse(status: 500, data: 'not-a-map'),
      );

      final result = await service.initiatePayment(
        amount: const Money.egp(100),
        method: PaymentMethod.paymobCard,
        orderId: 'ord-1',
        customerEmail: 'customer@example.com',
      );

      expect((result as PaymentFailed).message, 'Payment initiation failed');
    });

    test('empty checkout_url yields payment_session_invalid', () async {
      for (final data in <Object?>[
        const {'checkout_url': ''},
        const {'checkout_url': '   '},
        const {'checkout_url': 42},
        const <String, dynamic>{},
      ]) {
        stubInvoke(
          'paymob-initiate',
          FunctionResponse(status: 200, data: data),
        );

        final result = await service.initiatePayment(
          amount: const Money.egp(100),
          method: PaymentMethod.paymobCard,
          orderId: 'ord-1',
          customerEmail: 'customer@example.com',
        );

        expect(result, isA<PaymentFailed>());
        expect((result as PaymentFailed).code, 'payment_session_invalid');
      }
    });

    test('transport exception is scrubbed to payment_start_failed', () async {
      when(() =>
          functions.invoke('paymob-initiate',
              body: any(named: 'body'))).thenThrow(Exception(
          'POST https://accept.paymob.com/api/auth 401 token=SECRET_VALUE'));

      final result = await service.initiatePayment(
        amount: const Money.egp(100),
        method: PaymentMethod.paymobCard,
        orderId: 'ord-1',
        customerEmail: 'customer@example.com',
      );

      expect(result, isA<PaymentFailed>());
      final failure = result as PaymentFailed;
      expect(failure.code, 'payment_start_failed');
      expect(
          failure.message, 'Payment could not be started. Please try again.');
      expect(failure.message, isNot(contains('https://')));
      expect(failure.message, isNot(contains('SECRET_VALUE')));
    });
  });

  group('confirmCodPayment', () {
    test('ok=true returns the server transaction id', () async {
      stubRpc(
        'confirm_cod_payment',
        const {'ok': true, 'transaction_id': 'txn-server-1'},
      );

      final result = await service.confirmCodPayment(orderId: 'ord-1');

      expect(result, isA<PaymentSuccess>());
      final success = result as PaymentSuccess;
      expect(success.transactionId, 'txn-server-1');
      expect(success.amount, Money.zero);

      verify(() => client.rpc<dynamic>('confirm_cod_payment',
          params: {'p_order_id': 'ord-1'})).called(1);
    });

    test('ok=true without a transaction id degrades to empty string', () async {
      stubRpc('confirm_cod_payment', const {'ok': true});

      final result = await service.confirmCodPayment(orderId: 'ord-1');

      expect((result as PaymentSuccess).transactionId, '');
    });

    test('known failure codes map to user-safe messages', () async {
      stubRpc(
        'confirm_cod_payment',
        const {'ok': false, 'code': 'payment_not_pending'},
      );

      final result = await service.confirmCodPayment(orderId: 'ord-1');

      expect(result, isA<PaymentFailed>());
      final failure = result as PaymentFailed;
      expect(failure.code, 'payment_not_pending');
      expect(failure.message, 'This payment has already been processed.');
    });

    test('unknown failure code keeps the code and generic message', () async {
      stubRpc(
        'confirm_cod_payment',
        const {'ok': false, 'code': 'something_new'},
      );

      final failure =
          await service.confirmCodPayment(orderId: 'ord-1') as PaymentFailed;

      expect(failure.code, 'something_new');
      expect(failure.message, 'Failed to confirm payment. Please try again.');
    });

    test('malformed payload degrades to unknown + generic message', () async {
      for (final payload in <Object?>[
        null,
        'oops',
        <int>[1, 2]
      ]) {
        stubRpc('confirm_cod_payment', payload);

        final failure =
            await service.confirmCodPayment(orderId: 'ord-1') as PaymentFailed;

        expect(failure.code, 'unknown');
        expect(failure.message, 'Failed to confirm payment. Please try again.');
      }
    });

    test('timeout maps to rpc_timeout', () async {
      when(() => client.rpc<dynamic>('confirm_cod_payment',
          params: any(named: 'params'))).thenThrow(TimeoutException('slow'));

      final failure =
          await service.confirmCodPayment(orderId: 'ord-1') as PaymentFailed;

      expect(failure.code, 'rpc_timeout');
      expect(failure.message,
          'Server did not respond in time. Please check your orders and try again.');
    });

    test('transport exception is scrubbed to network_error', () async {
      when(() => client.rpc<dynamic>('confirm_cod_payment',
              params: any(named: 'params')))
          .thenThrow(Exception('token=SECRET_VALUE'));

      final failure =
          await service.confirmCodPayment(orderId: 'ord-1') as PaymentFailed;

      expect(failure.code, 'network_error');
      expect(failure.message, 'Failed to confirm payment. Please try again.');
      expect(failure.message, isNot(contains('SECRET_VALUE')));
    });
  });

  group('setOrderPaymentMethod', () {
    test('ok=true returns an empty-transaction success', () async {
      stubRpc('set_pending_order_payment_method', const {'ok': true});

      final result =
          await service.setOrderPaymentMethod(orderId: 'o1', method: 'cod');

      expect(result, isA<PaymentSuccess>());
      expect((result as PaymentSuccess).transactionId, '');
      verify(() => client.rpc<dynamic>('set_pending_order_payment_method',
          params: {'p_order_id': 'o1', 'p_method': 'cod'})).called(1);
    });

    test('known failure code maps to its message', () async {
      stubRpc('set_pending_order_payment_method',
          const {'ok': false, 'code': 'invalid_method'});

      final failure = await service.setOrderPaymentMethod(
          orderId: 'o1', method: 'gift') as PaymentFailed;

      expect(failure.code, 'invalid_method');
      expect(failure.message, 'Unsupported payment method.');
    });

    test('unknown/malformed payload yields unknown + generic', () async {
      for (final payload in <Object?>[
        const {'ok': false, 'code': 'brand_new'},
        null,
      ]) {
        stubRpc('set_pending_order_payment_method', payload);

        final failure = await service.setOrderPaymentMethod(
            orderId: 'o1', method: 'cod') as PaymentFailed;

        expect(failure.code, anyOf('brand_new', 'unknown'));
        expect(failure.message,
            anyOf('Failed to set payment method. Please try again.'));
      }
    });

    test('timeout maps to rpc_timeout', () async {
      when(() => client.rpc<dynamic>('set_pending_order_payment_method',
          params: any(named: 'params'))).thenThrow(TimeoutException('slow'));

      final failure = await service.setOrderPaymentMethod(
          orderId: 'o1', method: 'cod') as PaymentFailed;

      expect(failure.code, 'rpc_timeout');
    });

    test('transport exception is scrubbed to network_error', () async {
      when(() => client.rpc<dynamic>('set_pending_order_payment_method',
          params: any(named: 'params'))).thenThrow(Exception('SECRET_VALUE'));

      final failure = await service.setOrderPaymentMethod(
          orderId: 'o1', method: 'cod') as PaymentFailed;

      expect(failure.code, 'network_error');
      expect(
          failure.message, 'Failed to set payment method. Please try again.');
      expect(failure.message, isNot(contains('SECRET_VALUE')));
    });
  });

  group('initiateInstapayPayment', () {
    test('valid payload returns InstapayReady', () async {
      stubInvoke(
        'instapay-initiate',
        const FunctionResponse(status: 200, data: {
          'payment_id': 'pay-1',
          'instapay_address': 'instapay@merchant',
          'amount': 129000,
        }),
      );

      final result = await service.initiateInstapayPayment(orderId: 'ord-1');

      expect(result, isA<InstapayReady>());
      final instructions = (result as InstapayReady).instructions;
      expect(instructions.paymentId, 'pay-1');
      expect(instructions.instapayAddress, 'instapay@merchant');
      expect(instructions.amount, const Money(129000));
    });

    test('non-200 response maps the server message', () async {
      stubInvoke(
        'instapay-initiate',
        const FunctionResponse(
            status: 409, data: {'message': 'Order is not pending'}),
      );

      final result = await service.initiateInstapayPayment(orderId: 'ord-1');

      expect(result, isA<InstapayUnavailable>());
      expect((result as InstapayUnavailable).message, 'Order is not pending');
    });

    test('non-200 with malformed body uses the fallback message', () async {
      stubInvoke(
        'instapay-initiate',
        const FunctionResponse(status: 500, data: 42),
      );

      final result = await service.initiateInstapayPayment(orderId: 'ord-1');

      expect((result as InstapayUnavailable).message,
          'InstaPay is unavailable right now.');
    });

    test('invalid/partial payload yields instapay_session_invalid', () async {
      for (final data in <Object?>[
        const <String, dynamic>{},
        const {'payment_id': 'pay-1', 'instapay_address': 'a@b', 'amount': 0},
        const {'payment_id': '', 'instapay_address': 'a@b', 'amount': 100},
        const {'payment_id': 'pay-1', 'instapay_address': '', 'amount': 100},
        'oops',
      ]) {
        stubInvoke(
          'instapay-initiate',
          FunctionResponse(status: 200, data: data),
        );

        final result = await service.initiateInstapayPayment(orderId: 'ord-1');

        expect(result, isA<InstapayUnavailable>());
        expect(
            (result as InstapayUnavailable).code, 'instapay_session_invalid');
      }
    });

    test('timeout maps to rpc_timeout', () async {
      when(() =>
              functions.invoke('instapay-initiate', body: any(named: 'body')))
          .thenThrow(TimeoutException('slow'));

      final result = await service.initiateInstapayPayment(orderId: 'ord-1');

      expect((result as InstapayUnavailable).code, 'rpc_timeout');
    });

    test('transport exception is scrubbed to network_error', () async {
      when(() =>
              functions.invoke('instapay-initiate', body: any(named: 'body')))
          .thenThrow(Exception('https://internal.example token=SECRET'));

      final result = await service.initiateInstapayPayment(orderId: 'ord-1');

      final failure = result as InstapayUnavailable;
      expect(failure.code, 'network_error');
      expect(
          failure.message, 'InstaPay could not be started. Please try again.');
      expect(failure.message, isNot(contains('SECRET')));
    });
  });

  group('submitInstapayProof', () {
    test('empty proof is rejected before any network call', () async {
      final result = await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [],
        fileExt: 'png',
      );

      expect((result as PaymentFailed).code, 'proof_missing');
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('disallowed extension is rejected before any network call', () async {
      final result = await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [1, 2, 3],
        fileExt: 'GIF',
      );

      expect((result as PaymentFailed).code, 'unsupported_format');
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('201 returns success and sends normalized/base64 body', () async {
      stubInvoke(
        'instapay-submit-proof',
        const FunctionResponse(status: 201),
      );

      final result = await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [1, 2, 3],
        fileExt: ' PNG ',
        reference: '  TX-9  ',
      );

      expect(result, isA<PaymentSuccess>());
      final body = verify(() => functions.invoke('instapay-submit-proof',
          body: captureAny(named: 'body'))).captured.single as Map;
      expect(body['order_id'], 'ord-1');
      expect(body['file_ext'], 'png');
      expect(body['proof_base64'], base64Encode(const [1, 2, 3]));
      expect(body['reference'], 'TX-9');
    });

    test('blank reference is omitted from the body', () async {
      stubInvoke(
        'instapay-submit-proof',
        const FunctionResponse(status: 201),
      );

      await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [9],
        fileExt: 'jpg',
        reference: '   ',
      );

      final body = verify(() => functions.invoke('instapay-submit-proof',
          body: captureAny(named: 'body'))).captured.single as Map;
      expect(body.containsKey('reference'), isFalse);
    });

    test('non-201 maps known server messages', () async {
      stubInvoke(
        'instapay-submit-proof',
        const FunctionResponse(
            status: 413, data: {'message': 'Proof too large'}),
      );

      final failure = await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [1],
        fileExt: 'png',
      ) as PaymentFailed;

      expect(failure.message,
          'The screenshot is too large. Please attach a smaller image.');
    });

    test('non-201 with malformed body uses the fallback', () async {
      for (final data in <Object?>[
        null,
        'oops',
        const {'message': 42}
      ]) {
        stubInvoke(
          'instapay-submit-proof',
          FunctionResponse(status: 500, data: data),
        );

        final failure = await service.submitInstapayProof(
          orderId: 'ord-1',
          proofBytes: const [1],
          fileExt: 'png',
        ) as PaymentFailed;

        expect(
            failure.message, 'Could not submit the proof. Please try again.');
      }
    });

    test('timeout maps to rpc_timeout', () async {
      when(() => functions.invoke('instapay-submit-proof',
          body: any(named: 'body'))).thenThrow(TimeoutException('slow'));

      final failure = await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [1],
        fileExt: 'png',
      ) as PaymentFailed;

      expect(failure.code, 'rpc_timeout');
      expect(
          failure.message, 'Server did not respond in time. Please try again.');
    });

    test('transport exception is scrubbed to network_error', () async {
      when(() => functions.invoke('instapay-submit-proof',
              body: any(named: 'body')))
          .thenThrow(Exception('SECRET_VALUE https://internal'));

      final failure = await service.submitInstapayProof(
        orderId: 'ord-1',
        proofBytes: const [1],
        fileExt: 'png',
      ) as PaymentFailed;

      expect(failure.code, 'network_error');
      expect(failure.message, 'Could not submit the proof. Please try again.');
      expect(failure.message, isNot(contains('SECRET_VALUE')));
    });
  });
}
