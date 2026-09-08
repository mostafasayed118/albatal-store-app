import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentState', () {
    test('canProceed is true when method is selected', () {
      const state = PaymentState(
        status: PaymentStatus.selectingMethod,
        selectedMethod: PaymentMethod.paymobCard,
      );
      expect(state.canProceed, isTrue);
    });

    test('canProceed is false when no method selected', () {
      const state = PaymentState(status: PaymentStatus.selectingMethod);
      expect(state.canProceed, isFalse);
    });

    test('copyWith preserves all fields', () {
      const state = PaymentState(
        status: PaymentStatus.processing,
        selectedMethod: PaymentMethod.paymobCard,
        amount: Money.egp(1500),
        orderId: 'ORD-1',
      );
      final updated = state.copyWith(transactionId: 'TXN-1');
      expect(updated.transactionId, 'TXN-1');
      expect(updated.amount, Money.egp(1500));
      expect(updated.selectedMethod, PaymentMethod.paymobCard);
    });
  });

  group('PaymentResult', () {
    test('PaymentSuccess holds transactionId and amount', () {
      const result =
          PaymentSuccess(transactionId: 'TXN-1', amount: Money.egp(1500));
      expect(result.transactionId, 'TXN-1');
      expect(result.amount, Money.egp(1500));
    });

    test('PaymentFailed holds message and optional code', () {
      const result = PaymentFailed(message: 'Failed', code: 'E001');
      expect(result.message, 'Failed');
      expect(result.code, 'E001');
    });

    test('PaymentPending holds the hosted checkout URL', () {
      const result = PaymentPending(
        checkoutUrl: 'https://example.com/checkout',
      );
      expect(result.checkoutUrl, 'https://example.com/checkout');
    });

    test('PaymentCancelled has no fields', () {
      const result = PaymentCancelled();
      expect(result, isA<PaymentCancelled>());
    });
  });

  group('PaymentMethod', () {
    test('has correct labels', () {
      expect(PaymentMethod.paymobCard.label, 'Paymob Card');
      expect(PaymentMethod.cashOnDelivery.label, 'Cash on Delivery');
    });

    test('serverValue matches the strings the server gates on', () {
      // Migration 035 + paymob-initiate require orders.payment_method to be
      // exactly 'paymob_card' for card initiation; 018/022/026 confirm COD
      // via ILIKE '%cash%'/'%cod%'; 037/039 allowlist ('cod','card').
      expect(PaymentMethod.paymobCard.serverValue, 'paymob_card');
      expect(PaymentMethod.cashOnDelivery.serverValue, 'cod');
    });
  });

  group('PaymentCubit watch timer factory + code emits', () {
    late _StubPaymentService service;

    setUp(() {
      service = _StubPaymentService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('watch timeout fires via injected timer factory', () async {
      var fired = false;
      Timer fakeFactory(Duration d, void Function() cb) {
        fired = true;
        cb();
        return Timer(const Duration(milliseconds: 1), () {});
      }

      final cubit = PaymentCubit(service, timerFactory: fakeFactory);
      cubit.initPayment(amount: Money(100), orderId: 'O1');
      await cubit.startWatching('O1');
      expect(fired, isTrue);
      await cubit.close();
    });

    test('startWatching with blank order ref emits order_ref_required code',
        () async {
      for (final blank in ['', '  ']) {
        final cubit = PaymentCubit(service);
        cubit.initPayment(amount: Money(100), orderId: 'O1');
        await cubit.startWatching(blank);
        expect(cubit.state.status, PaymentStatus.failed);
        expect(cubit.state.errorMessage, 'order_ref_required');
        await cubit.close();
      }
    });

    test('watch stream error emits verify_failed code', () async {
      final cubit = PaymentCubit(service);
      cubit.initPayment(amount: Money(100), orderId: 'O1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(cubit.state.status, PaymentStatus.awaitingVerification);

      // Drive the server-status stream to error — the cubit must
      // surface the verify_failed code, not raw stream details.
      service.addWatchError(Exception('realtime down'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, 'verify_failed');
      await cubit.close();
    });

    test('watch stream error while awaitingProof is ignored', () async {
      service.instapayResult = InstapayReady(
        instructions: InstapayInstructions(
          paymentId: 'p1',
          instapayAddress: 'merchant@instapay',
          amount: Money(100),
        ),
      );
      final cubit = PaymentCubit(service);
      cubit.initPayment(amount: Money(100), orderId: 'O1');
      cubit.selectMethod(PaymentMethod.instapay);
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(cubit.state.status, PaymentStatus.awaitingProof);

      // The onError guard is awaitingVerification-only: an error here
      // must not flip the proof-upload state to failed.
      service.addWatchError(Exception('realtime down'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.status, PaymentStatus.awaitingProof);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test('injected factory timeout emits verify_timeout code', () async {
      void Function()? fireTimeout;
      Timer captureFactory(Duration d, void Function() cb) {
        fireTimeout = cb;
        return Timer(const Duration(minutes: 15), () {});
      }

      final cubit = PaymentCubit(service, timerFactory: captureFactory);
      cubit.initPayment(amount: Money(100), orderId: 'O1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(cubit.state.status, PaymentStatus.awaitingVerification);

      // Drive the injected timer's callback directly — no test-only API,
      // no real fifteen-minute wait.
      fireTimeout!();
      expect(cubit.state.status, PaymentStatus.timedOut);
      expect(cubit.state.errorMessage, 'verify_timeout');
      await cubit.close();
    });
  });
}

/// Minimal stub: card initiation stays pending so the cubit arms the
/// watch; the broadcast controller lets tests drive server results.
class _StubPaymentService implements PaymentService {
  final StreamController<PaymentResult> _controller =
      StreamController<PaymentResult>.broadcast();

  /// Drive the watched status stream to error.
  void addWatchError(Object error) => _controller.addError(error);

  /// InstaPay preparation result; defaults to unavailable so existing
  /// tests keep their behaviour.
  InstapayInitiation instapayResult =
      const InstapayUnavailable(message: 'stub');

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentPending(
        checkoutUrl:
            'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=t',
      );

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async =>
      const PaymentFailed(message: 'stub');

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async =>
      const PaymentFailed(message: 'stub');

  @override
  Future<InstapayInitiation> initiateInstapayPayment(
          {required String orderId}) async =>
      instapayResult;

  @override
  Future<PaymentResult> submitInstapayProof({
    required String orderId,
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
  }) async =>
      const PaymentFailed(message: 'stub');

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      _controller.stream;

  Future<void> dispose() => _controller.close();
}
