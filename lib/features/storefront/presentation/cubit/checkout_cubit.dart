import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/analytics_service.dart';
import '../../../../shared/services/logger.dart';
import '../../../payments/domain/entities/payment.dart';
import '../../domain/entities/coupon_discount.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../domain/repositories/coupons_repository.dart';
import '../../domain/repositories/idempotency_store.dart';
import '../../domain/repositories/memory_idempotency_store.dart';
import '../../domain/usecases/place_checkout_order_usecase.dart';

enum CheckoutStatus { initial, creatingOrder, placing, success, error }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.payment = PaymentMethod.paymobCard,
    this.selectedAddress,
    this.errorMessage,
    this.errorCode,
    this.pendingOrderId,
    this.serverSubtotal,
    this.serverShipping,
    this.serverTotal,
    this.expiresAt,
    this.idempotencyKey,
    this.appliedCoupon,
    this.couponMessage,
  });

  final CheckoutStatus status;
  final PaymentMethod payment;
  final Address? selectedAddress;
  final String? errorMessage;

  /// Machine-readable classification of [errorMessage] (e.g.
  /// [kCheckoutFailedCode]); the page maps it to localized copy
  /// instead of string-matching (audit 2026-09-13).
  final String? errorCode;
  final String? pendingOrderId;
  final Money? serverSubtotal;
  final Money? serverShipping;
  final Money? serverTotal;
  final DateTime? expiresAt;
  final String? idempotencyKey;

  /// Server-validated coupon attached to this checkout attempt (§8).
  final CouponDiscount? appliedCoupon;

  /// Machine-readable coupon outcome for the page to map to l10n
  /// (`coupon_invalid` / `coupon_unavailable`), null when settled.
  final String? couponMessage;

  bool get hasAddress => selectedAddress != null;
  bool get hasPendingOrder => pendingOrderId != null && serverTotal != null;

  /// Step index for the checkout progress indicator (0=Shipping, 1=Payment, 2=Confirm).
  int get step => switch (status) {
        CheckoutStatus.initial => 0,
        CheckoutStatus.creatingOrder => 1,
        CheckoutStatus.placing => 2,
        CheckoutStatus.success => 2,
        CheckoutStatus.error => 1,
      };

  CheckoutState copyWith({
    CheckoutStatus? status,
    PaymentMethod? payment,
    Address? selectedAddress,
    bool clearAddress = false,
    String? errorMessage,
    String? errorCode,
    String? pendingOrderId,
    Money? serverSubtotal,
    Money? serverShipping,
    Money? serverTotal,
    DateTime? expiresAt,
    String? idempotencyKey,
    CouponDiscount? appliedCoupon,
    bool clearCoupon = false,
    String? couponMessage,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        payment: payment ?? this.payment,
        selectedAddress:
            clearAddress ? null : (selectedAddress ?? this.selectedAddress),
        errorMessage: errorMessage,
        errorCode: errorCode,
        pendingOrderId: pendingOrderId ?? this.pendingOrderId,
        serverSubtotal: serverSubtotal ?? this.serverSubtotal,
        serverShipping: serverShipping ?? this.serverShipping,
        serverTotal: serverTotal ?? this.serverTotal,
        expiresAt: expiresAt ?? this.expiresAt,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        appliedCoupon:
            clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
        couponMessage: couponMessage,
      );

  @override
  List<Object?> get props => [
        status,
        payment,
        selectedAddress,
        errorMessage,
        errorCode,
        pendingOrderId,
        serverSubtotal,
        serverShipping,
        serverTotal,
        expiresAt,
        idempotencyKey,
        appliedCoupon,
        couponMessage,
      ];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(
    CheckoutRepository checkoutRepository, {
    // Production injects [placeOrder] from the composition root (the
    // router resolves the persisted IdempotencyStore via the use case);
    // the domain-located in-memory default keeps widget tests
    // construction-only. Either branch depends on domain ports only —
    // no service location, no data-layer imports (audit P1, re-closed
    // after the feature batch; audit P5 reviewed and kept: the default
    // builds a domain use case out of the already-injected repository,
    // so there is no hidden dependency to inject).
    PlaceCheckoutOrderUseCase? placeOrder,
    IdempotencyStore? idempotencyStore,
    CouponsRepository? coupons,
    AnalyticsService? analytics,
  })  : _coupons = coupons,
        _analytics = analytics,
        _placeOrder = placeOrder ??
            PlaceCheckoutOrderUseCase(
              checkoutRepository: checkoutRepository,
              idempotencyStore: idempotencyStore ?? MemoryIdempotencyStore(),
            ),
        super(const CheckoutState());

  final PlaceCheckoutOrderUseCase _placeOrder;
  final CouponsRepository? _coupons;
  final AnalyticsService? _analytics;

  /// Validates [code] via the server and attaches it to this attempt.
  ///
  /// Validation failures (invalid code, coupons backend not deployed
  /// yet) set [CheckoutState.couponMessage]; the checkout itself is
  /// unaffected either way.
  Future<void> applyCoupon(String code) async {
    final repo = _coupons;
    if (repo == null) {
      emit(state.copyWith(couponMessage: kCouponUnavailable));
      return;
    }
    final result = await repo.validate(code);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          appliedCoupon: value,
          clearCoupon: false,
          couponMessage: null,
        ));
      case Failure(:final error):
        emit(state.copyWith(
          clearCoupon: true,
          couponMessage: error.message,
        ));
    }
  }

  void clearCoupon() =>
      emit(state.copyWith(clearCoupon: true, couponMessage: null));

  void payment(PaymentMethod value) => emit(state.copyWith(payment: value));

  void selectAddress(Address address) =>
      emit(state.copyWith(selectedAddress: address));

  void clearAddress() => emit(state.copyWith(clearAddress: true));

  /// Create a pending order via the server-side checkout RPC.
  ///
  /// Returns the order_id and the server-computed totals so the
  /// payment layer can initiate Paymob with the real order id and
  /// amount. The order is created as "pending" — the paymob-callback
  /// webhook promotes it to "paid" on success, or cancels + restores
  /// stock on failure.
  ///
  /// Thin orchestration only: the idempotency key is generated on the
  /// first call and reused on subsequent calls (retries) for the same
  /// checkout attempt — that policy lives in [_placeOrder].
  Future<void> createPendingOrder({
    required List<CartItem> cartItems,
  }) async {
    // Double-tap guard: ignore re-entry while a creation is in flight.
    if (state.status == CheckoutStatus.creatingOrder ||
        state.status == CheckoutStatus.placing) {
      return;
    }
    // Empty-cart guard: never call the server with no items.
    // NOTE: no client-side address guard here on purpose — the server
    // rejects auth/other conditions before validating the address
    // (pinned by checkout_cubit_test "unauthorized caller rejection").
    if (cartItems.isEmpty) {
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Your cart is empty.',
        idempotencyKey: state.idempotencyKey,
      ));
      return;
    }
    emit(state.copyWith(status: CheckoutStatus.creatingOrder));
    try {
      final outcome = await _placeOrder(
        items: cartItems,
        paymentMethod: state.payment,
        address: state.selectedAddress,
        couponCode: state.appliedCoupon?.code,
        inSessionKey: state.idempotencyKey,
      );
      // page popped mid-flight: result has no home
      if (isClosed) return;
      // The outcome always carries the settled key — including on failure —
      // so the state key survives failed attempts and retries reuse it
      // (legacy behavior: the key was emitted before the repository call).
      if (outcome.isSuccess) {
        final placed = outcome.pending!;
        _analytics?.log(AnalyticsService.checkoutStart, {
          'order_id': placed.orderId,
          'items': cartItems.length,
        });
        emit(state.copyWith(
          status: CheckoutStatus.placing,
          idempotencyKey: outcome.idempotencyKey,
          pendingOrderId: placed.orderId,
          serverSubtotal: placed.subtotal,
          serverShipping: placed.shipping,
          serverTotal: placed.total,
          expiresAt: placed.expiresAt,
        ));
      } else {
        emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: outcome.error?.message ?? 'Failed to create order.',
          errorCode: outcome.error?.code,
          idempotencyKey: outcome.idempotencyKey,
        ));
      }
    } catch (e, st) {
      // close-triggered StateError is not a failure
      if (isClosed) return;
      // Generic user message — raw exception stays in logs only.
      Log.e('Create pending order failed', error: e, stackTrace: st);
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Failed to create order. Please try again.',
        errorCode: kCheckoutFailedCode,
        idempotencyKey: state.idempotencyKey,
      ));
    }
  }

  /// Reset the checkout state for a new attempt, clearing the
  /// idempotency key (and its persisted copy) so the next
  /// [createPendingOrder] gets a new one.
  ///
  /// Deliberately synchronous (pinned by tests): the in-session key is
  /// gone the moment this returns, and the underlying store's clear is
  /// synchronous as well.
  void resetForNewAttempt() {
    _placeOrder.clearPersistedKey();
    emit(CheckoutState(
      payment: state.payment,
      selectedAddress: state.selectedAddress,
    ));
  }

  void markSuccess() {
    _placeOrder.clearPersistedKey();
    _analytics?.log(AnalyticsService.purchase, {
      if (state.appliedCoupon != null) 'coupon': state.appliedCoupon!.code,
    });
    emit(state.copyWith(status: CheckoutStatus.success));
  }

  void markError(String message) =>
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: message));
}
