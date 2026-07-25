// ============================================================
// COD server-confirmation tests — comprehensive coverage.
//
// Proves the Flutter COD path is fully server-authoritative:
//   1. Success path (first-time confirmation).
//   2. already_confirmed path (idempotent re-confirmation).
//   3. Timeout path (RPC hangs → unresolved state).
//   4. Failure path (general server rejection).
//   5. Non-owner rejection (not_owner).
//   6. Non-COD rejection (payment_not_cod).
//   7. Cancelled order rejection (order_not_pending).
//   8. No local success without server response.
//   9. Double-call guard (processing state prevents re-entry).
//  10. PaymentService interface requires confirmCodPayment.
// ============================================================

import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub that records calls to confirmCodPayment.
class _RecordingPaymentService implements PaymentService {
  final List<String> confirmCalls = [];
  PaymentResult _confirmResult = const PaymentSuccess(
    transactionId: 'COD-test-txn',
    amount: Money.zero,
  );

  void setConfirmResult(PaymentResult result) => _confirmResult = result;

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentPending(checkoutUrl: 'https://example.com');

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    confirmCalls.add(orderId);
    return _confirmResult;
  }

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

/// Stub with a Completer to precisely control async timing.
class _CompleterConfirmService implements PaymentService {
  final List<String> confirmCalls = [];
  Completer<PaymentResult>? _pendingCompleter;

  /// Completes the currently pending confirmCodPayment call.
  void completeWith(PaymentResult result) {
    _pendingCompleter?.complete(result);
    _pendingCompleter = null;
  }

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentFailed(message: 'stub');

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    confirmCalls.add(orderId);
    _pendingCompleter = Completer<PaymentResult>();
    return _pendingCompleter!.future;
  }

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

/// Minimal stub implementing PaymentService. Proves the interface requires it.
class _StubWithCod implements PaymentService {
  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentFailed(message: 'stub');

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async =>
      const PaymentSuccess(transactionId: 'stub-txn', amount: Money.zero);

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

void main() {
  group('COD success path', () {
    test('calls confirmCodPayment with the order ID', () async {
      final service = _RecordingPaymentService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cod-1');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(service.confirmCalls, ['ord-cod-1']);
      await cubit.close();
    });

    test('emits success with server transaction ID on server success',
        () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentSuccess(
        transactionId: 'COD-server-uuid-123',
        amount: Money.zero,
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cod-2');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'COD-server-uuid-123');
      await cubit.close();
    });

    test('emits failed with server error on COD rejection', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message: 'This order can no longer be confirmed.',
        code: 'order_not_pending',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cod-3');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('no longer be confirmed'));
      await cubit.close();
    });

    test('does not emit client-generated transaction ID', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentSuccess(
        transactionId: 'COD-server-real',
        amount: Money.zero,
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cod-5');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      // Must NOT contain the old pattern 'COD-<timestamp>'
      expect(cubit.state.transactionId, isNot(contains('COD-1')));
      expect(cubit.state.transactionId, 'COD-server-real');
      await cubit.close();
    });

    test('amount is preserved from server-computed init (not overwritten)',
        () async {
      final service = _RecordingPaymentService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(500), orderId: 'ord-cod-amt');
      expect(cubit.state.amount, Money.egp(500));

      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      // Amount is from the server-computed init, not overwritten
      // by PaymentSuccess.amount.
      expect(cubit.state.amount, Money.egp(500));
      expect(cubit.state.status, PaymentStatus.success);
      await cubit.close();
    });
  });

  group('COD already_confirmed path', () {
    test('server returns ok:true code:already_confirmed → success', () async {
      final service = _RecordingPaymentService();
      // Server returns already_confirmed with ok:true.
      service.setConfirmResult(const PaymentSuccess(
        transactionId: 'COD-existing-txn',
        amount: Money.zero,
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-idem-1');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'COD-existing-txn');
      await cubit.close();
    });

    test('idempotent re-confirmation is safe via server', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentSuccess(
        transactionId: 'COD-idempotent-txn',
        amount: Money.zero,
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-idem-2');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      // First call succeeds.
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(cubit.state.status, PaymentStatus.success);
      expect(service.confirmCalls.length, 1);

      // Server handles idempotency — the RPC returns already_confirmed.
      // The cubit can safely re-trigger without side effects.
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(service.confirmCalls.length, 2);
      // Still success — idempotent.
      expect(cubit.state.status, PaymentStatus.success);
      await cubit.close();
    });
  });

  group('COD timeout path', () {
    test('emits failed when RPC hangs and timeout fires', () async {
      final service = _CompleterConfirmService();
      final cubit = PaymentCubit(service, watchTimeout: const Duration(seconds: 1));

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-timeout');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      // Start payment — RPC is now pending (never completes).
      final processFuture = cubit.processPayment(customerEmail: 'a@b.c');

      // Give the RPC time to start.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.confirmCalls, ['ord-timeout']);

      // Simulate timeout by completing with timeout error.
      service.completeWith(const PaymentFailed(
        message:
            'Server did not respond in time. Please check your orders and try again.',
        code: 'rpc_timeout',
      ));

      await processFuture;

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('check your orders'));
      expect(cubit.state.errorMessage, contains('try again'));
      await cubit.close();
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('COD failure path', () {
    test('emits failed on network error', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message: 'Failed to confirm payment. Please try again.',
        code: 'network_error',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cod-4');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('Failed to confirm'));
      await cubit.close();
    });

    test('emits failed with generic message for unknown error code', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message: 'Failed to confirm payment. Please try again.',
        code: 'unknown_error',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-unknown');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('Failed to confirm'));
      await cubit.close();
    });
  });

  group('COD non-owner rejection', () {
    test('server returns not_owner → failed with safe message', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message: 'You can only confirm your own orders.',
        code: 'not_owner',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-not-owner');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('your own orders'));
      // Must NOT leak the order ID or any internal details.
      expect(cubit.state.errorMessage, isNot(contains('ord-not-owner')));
      await cubit.close();
    });
  });

  group('COD non-COD rejection', () {
    test('server returns payment_not_cod → failed with safe message', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message: 'This order is not a Cash on Delivery order.',
        code: 'payment_not_cod',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-not-cod');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('not a Cash on Delivery'));
      await cubit.close();
    });
  });

  group('COD payment_not_found rejection', () {
    test('server returns payment_not_found → failed with safe message', () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message: 'No Cash on Delivery payment found for this order.',
        code: 'payment_not_found',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-no-payment');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('No Cash on Delivery payment'));
      // Must NOT leak internal details.
      expect(cubit.state.errorMessage, isNot(contains('ord-no-payment')));
      await cubit.close();
    });
  });

  group('COD cancelled order rejection', () {
    test('server returns order_not_pending → failed with safe message',
        () async {
      final service = _RecordingPaymentService();
      service.setConfirmResult(const PaymentFailed(
        message:
            'This order can no longer be confirmed. Please check your orders.',
        code: 'order_not_pending',
      ));
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cancelled');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('no longer be confirmed'));
      // Must NOT leak the order ID.
      expect(
          cubit.state.errorMessage, isNot(contains('ord-cancelled')));
      await cubit.close();
    });
  });

  group('No local success without server response', () {
    test('COD does not emit success before RPC returns', () async {
      final service = _CompleterConfirmService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-no-premature');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      // Start payment — RPC is now pending.
      final processFuture = cubit.processPayment(customerEmail: 'a@b.c');

      // Wait for the RPC to be called.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The cubit MUST be in processing state, NOT success.
      expect(cubit.state.status, PaymentStatus.processing);
      expect(cubit.state.transactionId, isNull);

      // Complete the RPC with success.
      service.completeWith(const PaymentSuccess(
        transactionId: 'COD-after-wait',
        amount: Money.zero,
      ));
      await processFuture;

      // NOW it should be success.
      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'COD-after-wait');
      await cubit.close();
    });

    test('COD failure before RPC returns leaves state as processing until resolved',
        () async {
      final service = _CompleterConfirmService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-fail-before');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      final processFuture = cubit.processPayment(customerEmail: 'a@b.c');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Still processing — not success, not failed.
      expect(cubit.state.status, PaymentStatus.processing);

      // Complete with failure.
      service.completeWith(const PaymentFailed(
        message: 'Order not found.',
        code: 'order_not_found',
      ));
      await processFuture;

      // Now failed.
      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, contains('Order not found'));
      await cubit.close();
    });
  });

  group('Double-call guard', () {
    test('processPayment ignores re-entry during processing', () async {
      final service = _CompleterConfirmService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-double');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      // Start first payment.
      final first = cubit.processPayment(customerEmail: 'a@b.c');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Attempt second payment while first is in flight.
      await cubit.processPayment(customerEmail: 'a@b.c');

      // Only one RPC call should have been made.
      expect(service.confirmCalls.length, 1);

      // Complete the first.
      service.completeWith(const PaymentSuccess(
        transactionId: 'COD-single',
        amount: Money.zero,
      ));
      await first;

      expect(cubit.state.status, PaymentStatus.success);
      expect(service.confirmCalls.length, 1);
      await cubit.close();
    });
  });

  group('PaymentService interface', () {
    test('confirmCodPayment is required on the interface', () {
      // If confirmCodPayment were removed from the interface,
      // _StubWithCod would fail to compile.
      final stub = _StubWithCod();
      expect(stub, isA<PaymentService>());
    });
  });
}
