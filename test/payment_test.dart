import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
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
        selectedMethod: PaymentMethod.vodafoneCash,
        amount: Money.egp(1500),
        orderId: 'ORD-1',
      );
      final updated = state.copyWith(transactionId: 'TXN-1');
      expect(updated.transactionId, 'TXN-1');
      expect(updated.amount, Money.egp(1500));
      expect(updated.selectedMethod, PaymentMethod.vodafoneCash);
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

    test('PaymentPending holds paymentKey', () {
      const result = PaymentPending(paymentKey: 'KEY-1');
      expect(result.paymentKey, 'KEY-1');
    });

    test('PaymentCancelled has no fields', () {
      const result = PaymentCancelled();
      expect(result, isA<PaymentCancelled>());
    });
  });

  group('PaymentMethod', () {
    test('has correct labels', () {
      expect(PaymentMethod.paymobCard.label, 'Paymob Card');
      expect(PaymentMethod.vodafoneCash.label, 'Vodafone Cash');
      expect(PaymentMethod.cashOnDelivery.label, 'Cash on Delivery');
    });
  });
}

