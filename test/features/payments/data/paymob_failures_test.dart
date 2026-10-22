import 'package:al_batal_elite/features/payments/data/paymob_failures.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('codFailureMessage', () {
    test('maps every documented code', () {
      const expected = {
        'authentication_required': 'Please sign in to confirm your order.',
        'payment_not_found':
            'No Cash on Delivery payment found for this order.',
        'not_owner': 'You can only confirm your own orders.',
        'payment_not_pending': 'This payment has already been processed.',
        'payment_not_cod': 'This order is not a Cash on Delivery order.',
        'order_not_found': 'Order not found.',
        'order_not_pending':
            'This order can no longer be confirmed. Please check your orders.',
        'already_confirmed':
            'This order was already confirmed. Please check your orders.',
      };
      for (final entry in expected.entries) {
        expect(codFailureMessage(entry.key), entry.value, reason: entry.key);
      }
    });

    test('unknown code falls back to the generic message', () {
      expect(codFailureMessage('something_else'),
          'Failed to confirm payment. Please try again.');
    });
  });

  group('setMethodFailureMessage', () {
    test('maps every documented code', () {
      const expected = {
        'authentication_required': 'Please sign in to continue.',
        'invalid_method': 'Unsupported payment method.',
        'not_owner': 'You can only modify your own orders.',
        'order_not_found': 'Order not found.',
        'order_not_pending':
            'This order can no longer be modified. Please check your orders.',
      };
      for (final entry in expected.entries) {
        expect(setMethodFailureMessage(entry.key), entry.value,
            reason: entry.key);
      }
    });

    test('unknown code falls back to the generic message', () {
      expect(setMethodFailureMessage('something_else'),
          'Failed to set payment method. Please try again.');
    });
  });

  group('proofServerFailureMessage', () {
    test('maps every documented server message', () {
      const expected = {
        'Pending InstaPay payment not found':
            'No pending InstaPay payment found for this order.',
        'Proof too large':
            'The screenshot is too large. Please attach a smaller image.',
        'Unsupported proof format': 'Unsupported screenshot format.',
        'Upload failed': 'Could not upload the screenshot. Please try again.',
      };
      for (final entry in expected.entries) {
        expect(proofServerFailureMessage(entry.key), entry.value,
            reason: entry.key);
      }
    });

    test('unknown/empty message falls back', () {
      expect(proofServerFailureMessage('new server error'),
          'Could not submit the proof. Please try again.');
      expect(proofServerFailureMessage(''),
          'Could not submit the proof. Please try again.');
    });
  });

  group('validateInstapayProof', () {
    test('empty bytes are rejected first with proof_missing', () {
      final result =
          validateInstapayProof(proofBytes: const [], ext: 'not-allowed');

      expect(result, isA<PaymentFailed>());
      expect(result!.message, 'Attach the transfer screenshot to continue.');
      expect(result.code, 'proof_missing');
    });

    test('all allowlisted extensions pass', () {
      for (final ext in const ['png', 'jpg', 'jpeg', 'webp']) {
        expect(
          validateInstapayProof(proofBytes: const [1], ext: ext),
          isNull,
          reason: ext,
        );
      }
    });

    test('non-allowlisted extensions are rejected', () {
      for (final ext in const ['', 'gif', 'png ', 'PNG']) {
        final result = validateInstapayProof(proofBytes: const [1], ext: ext);
        expect(result, isA<PaymentFailed>(), reason: ext);
        expect(result!.message, 'Unsupported screenshot format.');
        expect(result.code, 'unsupported_format');
      }
    });
  });

  group('initiate/timeout/network failure builders', () {
    test('paymobInitiateFailure keeps a string message', () {
      final failure =
          paymobInitiateFailure({'message': 'Server says no'}, fallback: 'FB');
      expect(failure.message, 'Server says no');
    });

    test('paymobInitiateFailure falls back for mistyped/absent payloads', () {
      for (final data in <Object?>[
        null,
        'oops',
        const <int>[1],
        const <String, dynamic>{},
        const {'message': 42},
      ]) {
        expect(paymobInitiateFailure(data, fallback: 'FB').message, 'FB');
      }
    });

    test('paymobTimeoutFailure carries rpc_timeout', () {
      final failure = paymobTimeoutFailure('too slow');
      expect(failure.message, 'too slow');
      expect(failure.code, 'rpc_timeout');
    });

    test('instapayInitiateFailure keeps/falls back the message', () {
      expect(
        instapayInitiateFailure({'message': 'Not configured'}, fallback: 'FB')
            .message,
        'Not configured',
      );
      expect(
        instapayInitiateFailure(const <String, dynamic>{}, fallback: 'FB')
            .message,
        'FB',
      );
    });

    test('instapayTimeoutFailure carries rpc_timeout', () {
      final failure = instapayTimeoutFailure('too slow');
      expect(failure.message, 'too slow');
      expect(failure.code, 'rpc_timeout');
    });

    test('instapayNetworkFailure scrubs the raw error', () {
      final failure = instapayNetworkFailure(
        error: Exception('https://paymob token=SECRET'),
        logMessage: 'instapay failed',
        message: 'Could not start InstaPay.',
      );

      expect(failure.message, 'Could not start InstaPay.');
      expect(failure.code, 'network_error');
      expect(failure.message, isNot(contains('SECRET')));
      expect(failure.message, isNot(contains('https://')));
    });

    test('paymobNetworkFailure scrubs the raw error and keeps the code', () {
      final failure = paymobNetworkFailure(
        error: Exception('https://paymob token=SECRET'),
        logMessage: 'paymob failed',
        message: 'Could not start payment.',
        code: 'payment_start_failed',
      );

      expect(failure.message, 'Could not start payment.');
      expect(failure.code, 'payment_start_failed');
      expect(failure.message, isNot(contains('SECRET')));
      expect(failure.message, isNot(contains('https://')));
    });

    test('paymobNetworkFailure defaults to network_error', () {
      final failure = paymobNetworkFailure(
        error: Exception('boom'),
        logMessage: 'paymob failed',
        message: 'Nope.',
      );
      expect(failure.code, 'network_error');
    });
  });
}
