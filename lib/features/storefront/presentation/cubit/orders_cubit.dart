import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/address.dart';
import '../../../../core/entities/order.dart';
import '../../domain/repositories/orders_repository.dart';
import '../cubit/cart_cubit.dart';

export '../../../../core/entities/order.dart';

typedef OrderIdGenerator = String Function();

String _defaultOrderId() {
  final now = DateTime.now();
  final suffix =
      now.millisecondsSinceEpoch.remainder(10000).toString().padLeft(4, '0');
  return 'ORD-${now.year}-$suffix';
}

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
  OrdersCubit(this._repository, {OrderIdGenerator generateId = _defaultOrderId})
      : _generateId = generateId,
        super(const OrdersState(status: OrdersStatus.initial));

  final OrdersRepository _repository;
  final OrderIdGenerator _generateId;

  Future<void> restore() async {
    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final stored = await _repository.readOrders();
      emit(OrdersState(orders: stored, status: OrdersStatus.ready));
    } catch (e) {
      emit(state.copyWith(
          status: OrdersStatus.error, errorMessage: 'Failed to load orders'));
    }
  }

  Order place(CartState cart,
      {required String paymentMethod, Address? address}) {
    final order = Order(
      id: _generateId(),
      items: List.of(cart.items),
      subtotal: cart.subtotal,
      shipping: cart.shipping,
      total: cart.total,
      status: OrderStatus.placed,
      placedAt: DateTime.now(),
      paymentMethod: paymentMethod,
      address: address,
    );
    final next = [order, ...state.orders];
    emit(OrdersState(orders: next, status: OrdersStatus.ready));
    _repository.writeOrders(next);
    return order;
  }

  void advance(String orderId) {
    try {
      final updated = state.orders.map((o) {
        if (o.id != orderId) return o;
        return switch (o.status) {
          OrderStatus.placed => o.copyWith(status: OrderStatus.shipped),
          OrderStatus.shipped => o.copyWith(status: OrderStatus.delivered),
          _ => o,
        };
      }).toList();
      emit(OrdersState(orders: updated, status: OrdersStatus.ready));
      _repository.writeOrders(updated);
    } catch (e) {
      emit(state.copyWith(
          status: OrdersStatus.error, errorMessage: 'Failed to update order'));
    }
  }
}
