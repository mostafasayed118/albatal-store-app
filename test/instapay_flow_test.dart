import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/instapay_stub.dart';

void main() {
  group('PaymentCubit — InstaPay (migration 041)', () {
    late InstapayStub stub;
    late PaymentCubit cubit;

    setUp(() {
      stub = InstapayStub(
        initiation: InstapayReady(instructions: readyInstructions),
      );
      cubit = buildReadyCubit(stub);
    });

    tearDown(() async {
      await cubit.close();
      await stub.watchController.close();
    });

    test('processPayment reaches awaitingProof with server instructions',
        () async {
      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.awaitingProof);
      expect(cubit.state.instructions, isNotNull);
      expect(
        cubit.state.instructions!.instapayAddress,
        'instapay@merchant',
      );
      // Server-authoritative amount, not the client-computed one.
      expect(cubit.state.instructions!.amount, readyInstructions.amount);
    });

    test('initiation failure surfaces a failed state', () async {
      stub.setInitiation(
        const InstapayUnavailable(message: 'InstaPay is not configured'),
      );

      await cubit.processPayment(customerEmail: 'a@b.c');

      expect(cubit.state.status, PaymentStatus.failed);
      expect(cubit.state.errorMessage, 'InstaPay is not configured');
    });

    test('submitInstapayProof succeeds and payment stays awaitingProof',
        () async {
      await cubit.processPayment(customerEmail: 'a@b.c');

      final ok = await cubit.submitInstapayProof(
        proofBytes: [1, 2, 3],
        fileExt: 'jpg',
        reference: 'op 1234',
      );

      expect(ok, isTrue);
      // Proof recorded ≠ paid: the payment stays pending until the
      // admin review (or the 24h expiry).
      expect(cubit.state.status, PaymentStatus.awaitingProof);
      expect(stub.proofCalls.single['file_ext'], 'jpg');
      expect(stub.proofCalls.single['reference'], 'op 1234');
    });

    test('submitInstapayProof rejection moves to failed', () async {
      stub.proofResult = const PaymentFailed(message: 'Upload failed');

      await cubit.processPayment(customerEmail: 'a@b.c');
      final ok = await cubit.submitInstapayProof(
        proofBytes: [1],
        fileExt: 'png',
      );

      expect(ok, isFalse);
      expect(cubit.state.status, PaymentStatus.failed);
    });

    test('submitInstapayProof outside awaitingProof is ignored', () async {
      final fresh = buildReadyCubit(stub);
      final ok = await fresh.submitInstapayProof(
        proofBytes: [1],
        fileExt: 'png',
      );
      expect(ok, isFalse);
      expect(fresh.state.status, PaymentStatus.selectingMethod);
      expect(stub.proofCalls, isEmpty);
      await fresh.close();
    });

    test('admin approval observed on the status stream completes the flow',
        () async {
      await cubit.processPayment(customerEmail: 'a@b.c');
      expect(cubit.state.status, PaymentStatus.awaitingProof);

      // The admin RPC flips the payments row server-side; the client
      // only observes it through the watch stream.
      stub.watchController.add(
        const PaymentSuccess(
          transactionId: 'instapay_proof_1',
          amount: Money.zero,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PaymentStatus.success);
      expect(cubit.state.transactionId, 'instapay_proof_1');
    });

    test('admin rejection observed on the status stream fails the flow',
        () async {
      await cubit.processPayment(customerEmail: 'a@b.c');

      stub.watchController.add(
        const PaymentFailed(message: 'Payment was declined by the gateway'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, PaymentStatus.failed);
    });
  });
}
