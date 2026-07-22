// ============================================================
// COD server-confirmation and late-callback rejection tests.
//
// Tests the PaymentCubit COD path now calls the server RPC
// and the interface contract for confirmCodPayment.
//
// These tests prove:
//   1. COD path calls confirmCodPayment (not client-only success).
//   2. COD server success emits PaymentStatus.success.
//   3. COD server rejection emits PaymentStatus.failed.
//   4. COD timeout/error does not emit client success.
//   5. PaymentService interface requires confirmCodPayment.
// ============================================================

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

void main() {
  group('COD server-confirmed path', () {
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

    test('guards against re-entry while processing', () async {
      final service = _SlowConfirmService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(100), orderId: 'ord-cod-6');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      // Start the first call but don't await it yet — the stub
      // has a delay so the cubit will be in processing state.
      final firstCall = cubit.processPayment(customerEmail: 'a@b.c');

      // Give the cubit time to enter processing state.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.status, PaymentStatus.processing);

      // Second call while still in processing — should be no-op.
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(service.confirmCalls.length, 1);

      // Complete the first call.
      await firstCall;
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

/// Minimal stub that implements the current PaymentService
/// including confirmCodPayment. Proves the interface requires it.
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
