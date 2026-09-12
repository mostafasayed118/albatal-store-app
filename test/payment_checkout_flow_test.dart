import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable stub for [PaymentService] used by the flow tests.
///
/// Exposes a [StreamController] so tests can drive server-side status
/// updates (simulating the webhook) and assert how the cubit reacts.
class _FlowStub implements PaymentService {
  _FlowStub();

  final StreamController<PaymentResult> _controller =
      StreamController<PaymentResult>.broadcast();

  PaymentResult? _initResult;
  int initiateCallCount = 0;
  String? lastOrderId;

  void setInitiateResult(PaymentResult r) => _initResult = r;

  void emitServerResult(PaymentResult r) => _controller.add(r);

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    initiateCallCount++;
    lastOrderId = orderId;
    return _initResult ??
        const PaymentPending(
          checkoutUrl:
              'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=t',
        );
  }

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async =>
      const PaymentFailed(message: 'stub');

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) {
    lastOrderId = orderId;
    return _controller.stream;
  }

  @override
  Future<InstapayInitiation> initiateInstapayPayment(
          {required String orderId}) async =>
      const InstapayUnavailable(message: 'stub: not exercised');

  @override
  Future<PaymentResult> submitInstapayProof({
    required String orderId,
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
  }) async =>
      const PaymentFailed(message: 'stub: not exercised');
  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async =>
      const PaymentFailed(message: 'stub');

  Future<void> close() => _controller.close();
}

void main() {
  group('PaymentCubit card flow', () {
    late _FlowStub service;
    late PaymentCubit cubit;

    setUp(() {
      service = _FlowStub();
      cubit = PaymentCubit(service);
    });

    tearDown(() async {
      await cubit.close();
      await service.close();
    });

    test('processPayment with pending emits awaitingVerification + checkoutUrl',
        () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-123');
      cubit.selectMethod(PaymentMethod.paymobCard);
      service.setInitiateResult(const PaymentPending(
        checkoutUrl:
            'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc',
      ));

      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.awaitingVerification);
      expect(cubit.state.checkoutUrl,
          'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc');
      expect(cubit.state.transactionId, isNull);
      expect(cubit.state.orderId, 'ord-123');
      // The cubit must start watching the real order id.
      expect(service.lastOrderId, 'ord-123');
    });

    test('server success transitions cubit to success and cancels subscription',
        () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');

      service.emitServerResult(
          const PaymentSuccess(transactionId: 'txn-real', amount: Money.zero));

      // Allow the stream listener to fire.
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'txn-real');
    });

    test('server failure transitions cubit to failed with message', () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');

      service.emitServerResult(const PaymentFailed(message: 'declined'));

      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, 'declined');
    });

    test('timeout emits timedOut and cancels the watch (no permanent loading)',
        () async {
      // The watch timer is injected: capture its callback and drive it
      // directly — no test-only API on the cubit, no real wait.
      void Function()? fireTimeout;
      final timedCubit = PaymentCubit(
        service,
        timerFactory: (Duration duration, void Function() callback) {
          fireTimeout = callback;
          return Timer(const Duration(minutes: 15), () {});
        },
      );
      timedCubit.initPayment(amount: const Money.egp(100), orderId: 'ord-1');
      timedCubit.selectMethod(PaymentMethod.paymobCard);
      await timedCubit.processPayment(customerEmail: 'a@b.c');

      fireTimeout!();

      expect(timedCubit.state.status, PaymentStatus.timedOut);
      expect(timedCubit.state.errorMessage, 'verify_timeout');
      await timedCubit.close();
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('cancel emits cancelled and cancels the watch', () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');

      cubit.cancel();

      expect(cubit.state.status, PaymentStatus.cancelled);
    });

    test('duplicate server success does not re-emit after terminal', () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');

      service.emitServerResult(
          const PaymentSuccess(transactionId: 'txn-1', amount: Money.zero));
      await Future<void>.delayed(Duration.zero);
      final firstStatus = cubit.state.status;
      expect(firstStatus, PaymentStatus.success);

      // A duplicate (e.g. late webhook replay) must not change state.
      service.emitServerResult(
          const PaymentSuccess(transactionId: 'txn-2', amount: Money.zero));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'txn-1');
    });

    test('close cancels the watch subscription and timer without throwing',
        () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');

      // Closing while a watch is active must not throw or leak.
      await cubit.close();
      // Re-close is a no-op.
      await cubit.close();
      expect(
          cubit.state.status,
          anyOf(
            PaymentStatus.awaitingVerification,
            PaymentStatus.timedOut,
          ));
    });

    test('initPayment with empty orderId keeps orderId empty (caller rejects)',
        () async {
      cubit.initPayment(amount: const Money.egp(100), orderId: '');
      expect(cubit.state.orderId, '');
      // The flow must NOT generate a fake order id internally.
      expect(cubit.state.status, PaymentStatus.selectingMethod);
    });
  });
}
