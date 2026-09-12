// H2 close guards: route-scoped cubits must not emit after close.
//
// CheckoutPage pops while createPendingOrder is in flight (the AppBar back
// button stays tappable during creatingOrder) and PaymentMethodPage disposes
// its PaymentCubit mid-RPC. A post-await emit() then throws StateError — in
// CheckoutCubit the catch block emitted again, escaping a second time.
// These tests pin the `if (isClosed) return;` guards: close mid-flight,
// release the RPC, and expect no throw plus no further emits.

import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _product = Product(
  id: 'p-h2',
  name: 'Test Silk',
  category: 'Silk',
  price: Money.egp(500),
  imageColor: 0xFF0B3D2E,
);

final _serverOrder = PendingOrder(
  orderId: 'ord-h2',
  subtotal: const Money.egp(500),
  shipping: const Money.egp(50),
  total: const Money.egp(550),
  expiresAt: DateTime.utc(2026, 1, 1),
);

/// CheckoutRepository whose placeOrder waits on a gate the test releases.
class _GatedCheckoutRepository implements CheckoutRepository {
  final Completer<Result<PendingOrder>> _gate =
      Completer<Result<PendingOrder>>();
  final Completer<void> entered = Completer<void>();

  void release(Result<PendingOrder> result) {
    if (!_gate.isCompleted) _gate.complete(result);
  }

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) {
    if (!entered.isCompleted) entered.complete();
    return _gate.future;
  }
}

/// PaymentService whose setOrderPaymentMethod waits on a gate the test
/// releases. confirmCodPayment must never be reached in the close test.
class _GatedPaymentService implements PaymentService {
  final Completer<PaymentResult> _methodGate = Completer<PaymentResult>();
  final Completer<void> enteredMethod = Completer<void>();
  final List<String> confirmCalls = <String>[];

  void releaseMethod(PaymentResult result) {
    if (!_methodGate.isCompleted) _methodGate.complete(result);
  }

  @override
  Future<PaymentResult> setOrderPaymentMethod({
    required String orderId,
    required String method,
  }) {
    if (!enteredMethod.isCompleted) enteredMethod.complete();
    return _methodGate.future;
  }

  @override
  Future<PaymentResult> confirmCodPayment({required String orderId}) async {
    confirmCalls.add(orderId);
    return const PaymentSuccess(transactionId: 'COD-late', amount: Money.zero);
  }

  @override
  Future<PaymentResult> initiatePayment({
    required Money amount,
    required PaymentMethod method,
    required String orderId,
    required String customerEmail,
  }) async =>
      const PaymentFailed(message: 'stub: not exercised');

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
  Stream<PaymentResult> watchPaymentStatus(String orderId) =>
      const Stream<PaymentResult>.empty();
}

void main() {
  group('H2 close guards', () {
    test('CheckoutCubit.createPendingOrder emits nothing after close',
        () async {
      final repo = _GatedCheckoutRepository();
      final cubit = CheckoutCubit(repo);

      final pending = cubit.createPendingOrder(
        cartItems: <CartItem>[
          const CartItem(
            product: _product,
            color: 'Emerald',
            length: '2m',
            quantity: 1,
          ),
        ],
      );
      await repo.entered.future;
      expect(cubit.state.status, CheckoutStatus.creatingOrder);

      // Subscribe after the loading emit so only post-close emits count.
      final emitted = <CheckoutState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.close();
      repo.release(Success(_serverOrder));
      await pending;

      expect(emitted, isEmpty);
      expect(cubit.state.status, CheckoutStatus.creatingOrder);
      await sub.cancel();
    });

    test('PaymentCubit COD emits nothing after close', () async {
      final service = _GatedPaymentService();
      final cubit = PaymentCubit(service);
      cubit.initPayment(amount: const Money.egp(100), orderId: 'ord-h2');
      cubit.selectMethod(PaymentMethod.cashOnDelivery);

      // Subscribe after init/select so only in-flight emits count.
      final emitted = <PaymentState>[];
      final sub = cubit.stream.listen(emitted.add);

      final processing = cubit.processPayment(customerEmail: 'a@b.c');
      await service.enteredMethod.future;
      expect(cubit.state.status, PaymentStatus.processing);

      await cubit.close();
      service.releaseMethod(
        const PaymentSuccess(transactionId: '', amount: Money.zero),
      );
      await processing;

      expect(service.confirmCalls, isEmpty);
      expect(emitted.single.status, PaymentStatus.processing);
      expect(cubit.state.status, PaymentStatus.processing);
      await sub.cancel();
    });
  });
}
