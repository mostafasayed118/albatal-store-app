import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../domain/repositories/checkout_repository.dart';

enum CheckoutStatus { initial, creatingOrder, placing, success, error }

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.payment = 'Credit Card',
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
  final String payment;
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
    String? payment,
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
  CheckoutCubit(this._checkoutRepository) : super(const CheckoutState());

  final CheckoutRepository _checkoutRepository;
  int _attemptCounter = 0;

  void payment(String value) => emit(state.copyWith(payment: value));

  void selectAddress(Address address) =>
      emit(state.copyWith(selectedAddress: address));

  void clearAddress() => emit(state.copyWith(clearAddress: true));

  /// Generate a stable idempotency key for this checkout attempt.
  ///
  /// The key is created once when the user first submits checkout and
  /// retained in the cubit state. On retry (network failure, user
  /// taps again) the same key is reused so the server returns the
  /// original order instead of creating a duplicate. When the user
  /// navigates away and starts a new checkout, a new cubit (and thus
  /// a new key) is created.
  String _generateIdempotencyKey() {
    _attemptCounter++;
    return 'cko-${DateTime.now().millisecondsSinceEpoch}-$_attemptCounter-${identityHashCode(this)}';
  }

  /// Create a pending order via the server-side checkout RPC.
  ///
  /// Returns the order_id and the server-computed totals so the
  /// payment layer can initiate Paymob with the real order id and
  /// amount. The order is created as "pending" — the paymob-callback
  /// webhook promotes it to "paid" on success, or cancels + restores
  /// stock on failure.
  ///
  /// The idempotency key is generated on the first call and reused
  /// on subsequent calls (retries) for the same checkout attempt.
  Future<void> createPendingOrder({
    required List<CartItem> cartItems,
  }) async {
    // Use the existing idempotency key if this is a retry, or
    // generate a new one for a fresh checkout attempt.
    final key = state.idempotencyKey ?? _generateIdempotencyKey();
    emit(state.copyWith(
      status: CheckoutStatus.creatingOrder,
      idempotencyKey: key,
    ));

    try {
      final result = await _checkoutRepository.placeOrder(
        items: cartItems,
        paymentMethod: state.payment,
        addressSnapshot: state.selectedAddress != null
            ? {
                'id': state.selectedAddress!.id,
                'recipient': state.selectedAddress!.recipient,
                'line': state.selectedAddress!.line,
                'city': state.selectedAddress!.city,
                'country': state.selectedAddress!.country,
              }
            : {},
        idempotencyKey: key,
      );

      result.when(
        success: (pending) => emit(state.copyWith(
          status: CheckoutStatus.placing,
          pendingOrderId: pending.orderId,
          serverSubtotal: pending.subtotal,
          serverShipping: pending.shipping,
          serverTotal: pending.total,
          expiresAt: pending.expiresAt,
        )),
        failure: (error) => emit(state.copyWith(
          status: CheckoutStatus.error,
          errorMessage: error.message,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: CheckoutStatus.error,
        errorMessage: 'Failed to create order: $e',
      ));
    }
  }

  /// Reset the checkout state for a new attempt, clearing the
  /// idempotency key so the next [createPendingOrder] gets a new one.
  void resetForNewAttempt() {
    emit(CheckoutState(
      payment: state.payment,
      selectedAddress: state.selectedAddress,
    ));
  }

  void markSuccess() => emit(state.copyWith(status: CheckoutStatus.success));
  void markError(String message) =>
      emit(state.copyWith(status: CheckoutStatus.error, errorMessage: message));
}
