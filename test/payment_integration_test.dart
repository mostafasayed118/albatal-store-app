import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stub payment service for testing.
class StubPaymentService implements PaymentService {
  PaymentResult? _resultToReturn;
  int callCount = 0;

  void setResult(PaymentResult result) => _resultToReturn = result;

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async {
    callCount++;
    return _resultToReturn ?? const PaymentFailed(message: 'No result set');
  }

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

void main() {
  group('PaymentCubit', () {
    late StubPaymentService service;
    late PaymentCubit cubit;

    setUp(() {
      service = StubPaymentService();
      cubit = PaymentCubit(service);
    });

    tearDown(() => cubit.close());

    test('initial state is PaymentStatus.initial', () {
      expect(cubit.state.status, PaymentStatus.initial);
    });

    test('initPayment sets selectingMethod status', () {
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      expect(cubit.state.status, PaymentStatus.selectingMethod);
      expect(cubit.state.amount, Money.egp(1500));
      expect(cubit.state.orderId, 'ORD-1');
    });

    test('selectMethod updates selected method', () {
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      expect(cubit.state.selectedMethod, PaymentMethod.paymobCard);
      expect(cubit.state.canProceed, isTrue);
    });

    test('processPayment with Cash on Delivery goes to success', () async {
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      await cubit.processPayment(customerEmail: 'test@test.com');

      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, startsWith('COD-'));
    });

    test('processPayment with failure sets error', () async {
      service.setResult(const PaymentFailed(message: 'Insufficient funds'));
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      cubit.selectMethod(PaymentMethod.paymobCard);

      await cubit.processPayment(customerEmail: 'test@test.com');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, 'Insufficient funds');
    });

    test('processPayment with pending sets awaitingVerification', () async {
      service.setResult(const PaymentPending(
        checkoutUrl: 'https://example.com/checkout',
      ));
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      cubit.selectMethod(PaymentMethod.paymobCard);

      await cubit.processPayment(customerEmail: 'test@test.com');

      expect(cubit.state.status, PaymentStatus.awaitingVerification);
      expect(cubit.state.transactionId, isNull);
      expect(cubit.state.checkoutUrl, 'https://example.com/checkout');
    });

    test('cancel sets cancelled status', () {
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      cubit.cancel();
      expect(cubit.state.status, PaymentStatus.cancelled);
    });

    test('reset returns to initial state', () {
      cubit.initPayment(amount: Money.egp(1500), orderId: 'ORD-1');
      cubit.selectMethod(PaymentMethod.paymobCard);
      cubit.reset();
      expect(cubit.state.status, PaymentStatus.initial);
      expect(cubit.state.selectedMethod, isNull);
    });
  });
}
