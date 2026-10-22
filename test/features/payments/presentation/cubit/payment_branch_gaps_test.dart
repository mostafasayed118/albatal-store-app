import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Service implements PaymentService {
  final StreamController<PaymentResult> watch =
      StreamController<PaymentResult>.broadcast();

  PaymentResult methodResult =
      const PaymentSuccess(transactionId: 'm', amount: Money.zero);
  PaymentResult cardResult = const PaymentPending(
      checkoutUrl:
          'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=t');
  PaymentResult codResult = const PaymentFailed(message: 'stub');
  PaymentResult proofResult = const PaymentFailed(message: 'stub');
  InstapayInitiation instapayResult =
      const InstapayUnavailable(message: 'stub');

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      cardResult;

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async =>
      codResult;

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async =>
      methodResult;

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
      proofResult;

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) => watch.stream;

  Future<void> dispose() => watch.close();
}

void main() {
  late _Service service;

  setUp(() {
    service = _Service();
  });

  tearDown(() async {
    await service.dispose();
  });

  PaymentCubit started(PaymentMethod method) {
    final cubit = PaymentCubit(service);
    cubit.initPayment(amount: const Money(100), orderId: 'O1');
    cubit.selectMethod(method);
    return cubit;
  }

  test('submitInstapayProof treats pending and cancelled as not recorded',
      () async {
    service.instapayResult = const InstapayReady(
      instructions: InstapayInstructions(
        paymentId: 'p1',
        instapayAddress: 'merchant@instapay',
        amount: Money(100),
      ),
    );
    final cubit = started(PaymentMethod.instapay);
    await cubit.processPayment(customerEmail: 'a@b.c');
    expect(cubit.state.status, PaymentStatus.awaitingProof);

    service.proofResult = const PaymentPending(checkoutUrl: '');
    expect(
        await cubit.submitInstapayProof(proofBytes: const [1], fileExt: 'png'),
        isFalse);

    service.proofResult = const PaymentCancelled();
    expect(
        await cubit.submitInstapayProof(proofBytes: const [1], fileExt: 'png'),
        isFalse);

    await cubit.close();
  });

  test('watcher ignores pending and completes on cancelled', () async {
    final cubit = started(PaymentMethod.paymobCard);
    await cubit.processPayment(customerEmail: 'a@b.c');
    expect(cubit.state.status, PaymentStatus.awaitingVerification);

    service.watch.add(const PaymentPending(checkoutUrl: ''));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, PaymentStatus.awaitingVerification);

    service.watch.add(const PaymentCancelled());
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, PaymentStatus.cancelled);

    await cubit.close();
  });

  test('card method failure emits the coded failure', () async {
    service.methodResult =
        const PaymentFailed(message: 'nope', code: 'method_failed');
    final cubit = started(PaymentMethod.paymobCard);

    await cubit.processPayment(customerEmail: 'a@b.c');

    expect(cubit.state.status, PaymentStatus.failed);
    expect(cubit.state.errorMessage, 'method_failed');
    await cubit.close();
  });

  test('card success and cancellation are terminal', () async {
    final success = started(PaymentMethod.paymobCard);
    service.cardResult =
        const PaymentSuccess(transactionId: 'txn', amount: Money(100));
    await success.processPayment(customerEmail: 'a@b.c');
    expect(success.state.status, PaymentStatus.success);
    expect(success.state.transactionId, 'txn');
    await success.close();

    final cancelled = started(PaymentMethod.paymobCard);
    service.cardResult = const PaymentCancelled();
    await cancelled.processPayment(customerEmail: 'a@b.c');
    expect(cancelled.state.status, PaymentStatus.cancelled);
    await cancelled.close();
  });

  test('COD pending becomes a terminal failure; cancelled stays cancelled',
      () async {
    final pending = started(PaymentMethod.cashOnDelivery);
    service.codResult = const PaymentPending(checkoutUrl: '');
    await pending.processPayment(customerEmail: 'a@b.c');
    expect(pending.state.status, PaymentStatus.failed);
    expect(pending.state.errorMessage, 'payment_not_pending');
    await pending.close();

    final cancelled = started(PaymentMethod.cashOnDelivery);
    service.codResult = const PaymentCancelled();
    await cancelled.processPayment(customerEmail: 'a@b.c');
    expect(cancelled.state.status, PaymentStatus.cancelled);
    await cancelled.close();
  });
}
