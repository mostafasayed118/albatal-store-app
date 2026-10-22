import 'dart:async';

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/coupon_discount.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/pending_order.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/coupons_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/checkout_cubit.dart';
import 'package:al_batal_elite/shared/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

final class _SuccessRepo implements CheckoutRepository {
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) async =>
      Success(PendingOrder(
        orderId: 'ORD-1',
        subtotal: const Money.egp(100),
        shipping: const Money.egp(10),
        total: const Money.egp(110),
        expiresAt: DateTime.utc(2026, 10, 21),
      ));
}

final class _ThrowingRepo implements CheckoutRepository {
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) async =>
      throw StateError('transport exploded');
}

final class _PendingRepo implements CheckoutRepository {
  final Completer<Result<PendingOrder>> completer =
      Completer<Result<PendingOrder>>();

  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Address? address,
    String? couponCode,
    String? idempotencyKey,
  }) =>
      completer.future;
}

final class _RecordingSink implements AnalyticsSink {
  final List<({String name, Map<String, dynamic> props})> events = [];

  @override
  Future<void> send(String name, Map<String, dynamic> props) async {
    events.add((name: name, props: props));
  }

  @override
  Future<void> sendBatch(
      List<({String name, Map<String, dynamic> props})> events) async {
    for (final event in events) {
      await send(event.name, event.props);
    }
  }
}

final class _Coupons implements CouponsRepository {
  @override
  Future<Result<CouponDiscount>> validate(String code) async =>
      Success(CouponDiscount(code: code, discountMinor: 500));
}

const _item = CartItem(
  product: Product(
    id: 'silk-01',
    name: 'Royal Emerald Silk',
    category: 'Silk',
    price: Money.egp(100),
    imageColor: 0xFF176B57,
  ),
  color: 'Emerald',
  length: '1m',
);

void main() {
  test('step maps every checkout status to its indicator index', () {
    expect(const CheckoutState().step, 0);
    expect(
      const CheckoutState(status: CheckoutStatus.creatingOrder).step,
      1,
    );
    expect(const CheckoutState(status: CheckoutStatus.placing).step, 2);
    expect(const CheckoutState(status: CheckoutStatus.success).step, 2);
    expect(const CheckoutState(status: CheckoutStatus.error).step, 1);
  });

  test('applyCoupon without a coupon backend reports unavailable', () async {
    final cubit = CheckoutCubit(_SuccessRepo());
    addTearDown(cubit.close);

    await cubit.applyCoupon('SAVE10');

    expect(cubit.state.appliedCoupon, isNull);
    expect(cubit.state.couponMessage, kCouponUnavailable);
  });

  test('a successful placement logs checkout_start with order context',
      () async {
    final sink = _RecordingSink();
    final analytics = AnalyticsService(sink: sink);
    addTearDown(analytics.dispose);
    final cubit = CheckoutCubit(
      _SuccessRepo(),
      coupons: _Coupons(),
      analytics: analytics,
    );
    addTearDown(cubit.close);

    await cubit.createPendingOrder(cartItems: [_item]);
    await analytics.flush();

    final event = sink.events.single;
    expect(event.name, AnalyticsService.checkoutStart);
    expect(event.props['order_id'], 'ORD-1');
    expect(event.props['items'], 1);
  });

  test('a thrown repository failure maps to the coded generic error', () async {
    final cubit = CheckoutCubit(_ThrowingRepo());
    addTearDown(cubit.close);

    await cubit.createPendingOrder(cartItems: [_item]);

    expect(cubit.state.status, CheckoutStatus.error);
    expect(cubit.state.errorCode, kCheckoutFailedCode);
    expect(cubit.state.errorMessage, contains('Please try again'));
  });

  test('closing mid-flight does not emit from the error continuation',
      () async {
    final repo = _PendingRepo();
    final cubit = CheckoutCubit(repo);

    final placement = cubit.createPendingOrder(cartItems: [_item]);
    await cubit.close();
    repo.completer.completeError(StateError('late transport failure'));

    await placement;
    expect(cubit.isClosed, isTrue);
  });

  test('a failure outcome keeps the settled idempotency key', () async {
    final cubit = CheckoutCubit(_SuccessRepo());
    addTearDown(cubit.close);

    await cubit.createPendingOrder(cartItems: [_item]);
    final key = cubit.state.idempotencyKey;
    expect(key, isNotNull);

    cubit.markError('Network down');
    expect(cubit.state.status, CheckoutStatus.error);
    expect(cubit.state.errorCode, kCheckoutFailedCode);
    expect(cubit.state.idempotencyKey, key);
  });
}
