// ============================================================
// COD payment-method handshake tests (migration 037).
//
// The checkout creates the order BEFORE the customer picks a
// method, so the COD path must first record the choice
// server-side (`set_pending_order_payment_method`) and only
// then call `confirm_cod_payment` (which requires a COD-like
// stored method, else `payment_not_cod`).
//
// Proves:
//   1. processPayment(COD) calls setOrderPaymentMethod('cod') first.
//   2. confirmCodPayment runs only after the method update succeeds.
//   3. A failed method update short-circuits: no confirm call,
//      cubit ends in failed with the server message.
//   4. Card flow does NOT touch setOrderPaymentMethod.
// ============================================================

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _SequenceRecordingService implements PaymentService {
  final List<String> calls = [];
  PaymentResult methodResult = const PaymentSuccess(
    transactionId: '',
    amount: Money.zero,
  );
  PaymentResult confirmResult = const PaymentSuccess(
    transactionId: 'COD-server-txn-037',
    amount: Money.zero,
  );

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    calls.add('initiate:$orderId');
    return const PaymentPending(checkoutUrl: 'https://example.com');
  }

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    calls.add('confirm:$orderId');
    return confirmResult;
  }

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async {
    calls.add('set-method:$orderId:$method');
    return methodResult;
  }

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

void main() {
  group('COD method handshake (migration 037)', () {
    test('records cod method before confirming', () async {
      final service = _SequenceRecordingService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(820), orderId: 'ord-037-1');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(service.calls, [
        'set-method:ord-037-1:cod',
        'confirm:ord-037-1',
      ]);
      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'COD-server-txn-037');

      await cubit.close();
    });

    test('failed method update short-circuits without confirm', () async {
      final service = _SequenceRecordingService()
        ..methodResult = const PaymentFailed(
          message: 'This order can no longer be modified.',
          code: 'order_not_pending',
        );
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(820), orderId: 'ord-037-2');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(service.calls, ['set-method:ord-037-2:cod']);
      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, 'This order can no longer be modified.');

      await cubit.close();
    });

    test('card flow never calls setOrderPaymentMethod', () async {
      final service = _SequenceRecordingService();
      final cubit = PaymentCubit(service);

      cubit.initPayment(amount: Money.egp(820), orderId: 'ord-037-3');
      cubit.selectMethod(PaymentMethod.paymobCard);
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(
        service.calls.where((c) => c.startsWith('set-method:')),
        isEmpty,
      );
      expect(service.calls, ['initiate:ord-037-3']);

      await cubit.close();
    });
  });
}
