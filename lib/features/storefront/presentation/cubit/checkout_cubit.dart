import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../shared/services/logger.dart';
import '../../../payments/domain/entities/payment.dart';
import '../../data/memory_idempotency_store.dart';
import '../../data/storefront_persistence.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../domain/repositories/idempotency_store.dart';
import '../../domain/usecases/place_checkout_order_usecase.dart';

enum CheckoutStatus { initial, creatingOrder, placing, success, error }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.payment = PaymentMethod.paymobCard,
    this.selectedAddress,
    this.errorMessage,
    this.pendingOrderId,
    this.serverSubtotal,
    this.serverShipping,
    this.serverTotal,
    this.expiresAt,
    this.idempotencyKey,
  });

  final CheckoutStatus status;
  final PaymentMethod payment;
  final Address? selectedAddress;
  final String? errorMessage;
  final String? pendingOrderId;
  final Money? serverSubtotal;
  final Money? serverShipping;
  final Money? serverTotal;
  final DateTime? expiresAt;
  final String? idempotencyKey;

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
    String? pendingOrderId,
    Money? serverSubtotal,
    Money? serverShipping,
    Money? serverTotal,
    DateTime? expiresAt,
    String? idempotencyKey,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        payment: payment ?? this.payment,
        selectedAddress:
            clearAddress ? null : (selectedAddress ?? this.selectedAddress),
        errorMessage: errorMessage,
        pendingOrderId: pendingOrderId ?? this.pendingOrderId,
        serverSubtotal: serverSubtotal ?? this.serverSubtotal,
        serverShipping: serverShipping ?? this.serverShipping,
        serverTotal: serverTotal ?? this.serverTotal,
        expiresAt: expiresAt ?? this.expiresAt,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      );

  @override
  List<Object?> get props => [
        status,
        payment,
        selectedAddress,
        errorMessage,
        pendingOrderId,
        serverSubtotal,
        serverShipping,
        serverTotal,
        expiresAt,
        idempotencyKey,
      ];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(
    CheckoutRepository checkoutRepository, {
    // Legacy persistence param (kept for backward compatibility — prefer
    // injecting [placeOrder], which already carries its store). Only used
    // to build the default use-case below; never read directly.
    SharedPreferences? prefs,
    PlaceCheckoutOrderUseCase? placeOrder,
    IdempotencyStore? idempotencyStore,
  })  : _placeOrder = placeOrder ??
            PlaceCheckoutOrderUseCase(
              checkoutRepository: checkoutRepository,
              idempotencyStore: idempotencyStore ??
                  (prefs == null
                      ? MemoryIdempotencyStore()
                      : LocalStorefrontPersistence(prefs)),
            ),
        super(const CheckoutState());

  final PlaceCheckoutOrderUseCase _placeOrder;

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
    emit(state.copyWith(status: CheckoutStatus.creatingOrder));
    try {
      final outcome = await _placeOrder(
        items: cartItems,
        paymentMethod: state.payment,
        address: state.selectedAddress,
        inSessionKey: state.idempotencyKey,
      );
      // The outcome always carries the settled key — including on failure —
      // so the state key survives failed attempts and retries reuse it
      // (legacy behavior: the key was emitted before the repository call).
      if (outcome.isSuccess) {
        final placed = outcome.pending!;
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
          idempotencyKey: outcome.idempotencyKey,
        ));
      }
    } catch (e) {
      // Generic user message — raw exception stays in logs only.
      Log.e('Create pending order failed', error: e);
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Failed to create order. Please try again.',
      ));
    }
  }

  /// Reset the checkout state for a new attempt, clearing the
  /// idempotency key (and its persisted copy) so the next
  /// [createPendingOrder] gets a new one.
  void resetForNewAttempt() {
    _placeOrder.clearPersistedKey();
    emit(CheckoutState(
      payment: state.payment,
      selectedAddress: state.selectedAddress,
    ));
  }

  void markSuccess() {
    _placeOrder.clearPersistedKey();
    emit(state.copyWith(status: CheckoutStatus.success));
  }

  void markError(String message) =>
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: message));
}
