import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/order.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/orders_repository.dart';

export '../../../../core/entities/order.dart';

enum OrdersStatus { initial, loading, ready, error }

final class OrdersState extends Equatable {
  const OrdersState({
    this.orders = const [],
    this.status = OrdersStatus.ready,
    this.errorMessage,
  });

  final List<Order> orders;
  final OrdersStatus status;
  final String? errorMessage;

  List<Order> get active => orders
      .where((o) =>
          o.status == OrderStatus.pending ||
          o.status == OrderStatus.placed ||
          o.status == OrderStatus.paid ||
          o.status == OrderStatus.processing ||
          o.status == OrderStatus.shipped)
      .toList()
    ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  List<Order> get completed =>
      orders.where((o) => o.status == OrderStatus.delivered).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  List<Order> get cancelled =>
      orders.where((o) => o.status == OrderStatus.cancelled).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

  OrdersState copyWith({
    List<Order>? orders,
    OrdersStatus? status,
    String? errorMessage,
  }) =>
      OrdersState(
        orders: orders ?? this.orders,
        status: status ?? this.status,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [orders, status, errorMessage];
}

final class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._repository)
      : super(const OrdersState(status: OrdersStatus.initial));

  final OrdersRepository _repository;

  Future<void> restore() async {
    emit(state.copyWith(status: OrdersStatus.loading));
    final result = await _repository.readOrders();
    switch (result) {
      case Success(:final value):
        emit(OrdersState(orders: value, status: OrdersStatus.ready));
      case Failure(:final error):
        emit(state.copyWith(
          status: OrdersStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Client-side order creation is intentionally removed.
  ///
  /// Orders must be created via the server-side checkout RPC
  /// (CheckoutService.createPendingOrder), not client-side.
  /// Use [reconcile] to merge server-created orders into local history.

  /// Client-side order progression is intentionally removed.
  ///
  /// Order status must be driven by server-side events (payment callbacks,
  /// admin actions, or scheduled expiry). Client-only progression via
  /// [advance] previously misled users about canonical order/payment status.
  /// Use [reconcile] to merge server-confirmed status changes into local history.
  Future<void> advance(String orderId) async {
    emit(state.copyWith(
      status: OrdersStatus.error,
      errorMessage: 'Order status updates are server-managed. '
          'Refresh to see the latest status.',
    ));
  }

  /// Idempotently merge a server-created order into local history.
  ///
  /// Matches by [Order.id]. If an order with the same ID already
  /// exists, it is replaced (upsert). If not, the order is
  /// appended. This satisfies spec 02 req 5: "reconcile
  /// callback/webhook-confirmed orders into local order history
  /// idempotently."
  Future<void> reconcile(Order serverOrder) async {
    final updated = <Order>[
      for (final o in state.orders)
        if (o.id == serverOrder.id) serverOrder else o,
    ];
    // If no existing order matched, append the server order.
    if (!updated.any((o) => o.id == serverOrder.id)) {
      updated.add(serverOrder);
    }
    emit(OrdersState(orders: updated, status: OrdersStatus.ready));
    final result = await _repository.writeOrders(updated);
    if (result case Failure(:final error)) {
      emit(state.copyWith(
        status: OrdersStatus.error,
        errorMessage: error.message,
      ));
    }
  }
}
