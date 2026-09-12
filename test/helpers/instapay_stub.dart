import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';

/// Controllable stub shared by the InstaPay cubit and widget tests:
/// initiation returns server-derived instructions; the watch stream is
/// a test-owned controller so tests can emulate the admin approval /
/// rejection arriving from the server.
class InstapayStub implements PaymentService {
  InstapayStub({InstapayInitiation? initiation})
      : _initiation = initiation ?? const InstapayUnavailable(message: 'stub');

  InstapayInitiation _initiation;
  final StreamController<PaymentResult> watchController =
      StreamController<PaymentResult>.broadcast();
  final List<Map<String, dynamic>> proofCalls = [];

  void setInitiation(InstapayInitiation initiation) => _initiation = initiation;

  PaymentResult? proofResult;

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
      const PaymentFailed(message: 'stub');

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) async =>
      const PaymentSuccess(transactionId: '', amount: Money.zero);

  @override
  Future<InstapayInitiation> initiateInstapayPayment(
      {required String orderId}) async {
    return _initiation;
  }

  @override
  Future<PaymentResult> submitInstapayProof({
    required String orderId,
    required List<int> proofBytes,
    required String fileExt,
    String? reference,
  }) async {
    proofCalls.add({
      'order_id': orderId,
      'bytes': proofBytes,
      'file_ext': fileExt,
      'reference': reference,
    });
    return proofResult ??
        const PaymentSuccess(transactionId: '', amount: Money.zero);
  }

  @override
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      watchController.stream;
}

const readyInstructions = InstapayInstructions(
  paymentId: 'pay-1',
  instapayAddress: 'instapay@merchant',
  amount: Money(129000),
);

PaymentCubit buildReadyCubit(InstapayStub stub) => PaymentCubit(stub)
  ..initPayment(amount: const Money.egp(1290), orderId: 'ord-1')
  ..selectMethod(PaymentMethod.instapay);
