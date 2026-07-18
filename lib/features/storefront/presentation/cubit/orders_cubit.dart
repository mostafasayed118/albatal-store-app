import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/order.dart';
import '../../data/storefront_persistence.dart';
import '../cubit/cart_cubit.dart';

export '../../../../core/entities/order.dart';

typedef OrderIdGenerator = String Function();

String _defaultOrderId() {
  final now = DateTime.now();
  final suffix = now.millisecondsSinceEpoch.remainder(10000).toString().padLeft(4, '0');
  return 'ORD-${now.year}-$suffix';
}

final class OrdersState extends Equatable {
  const OrdersState({this.orders = const [], this.status = OrdersStatus.ready});

  final List<Order> orders;
  final OrdersStatus status;

  List<Order> get active =>
      orders.where((o) => o.status == OrderStatus.placed || o.status == OrderStatus.shipped).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  List<Order> get completed =>
      orders.where((o) => o.status == OrderStatus.delivered).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  List<Order> get cancelled =>
      orders.where((o) => o.status == OrderStatus.cancelled).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

  OrdersState copyWith({List<Order>? orders, OrdersStatus? status}) =>
      OrdersState(orders: orders ?? this.orders, status: status ?? this.status);

  @override
  List<Object?> get props => [orders, status];
}

enum OrdersStatus { initial, loading, ready }

final class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._persistence, {OrderIdGenerator generateId = _defaultOrderId})
      : _generateId = generateId,
        super(const OrdersState(status: OrdersStatus.initial));

  final StorefrontPersistence _persistence;
  final OrderIdGenerator _generateId;

  Future<void> restore() async {
    emit(state.copyWith(status: OrdersStatus.loading));
    final stored = await _persistence.readOrders();
    emit(OrdersState(orders: stored, status: OrdersStatus.ready));
  }

  /// Snapshots the current cart into a new [Order], persists it, and emits.
  /// Does NOT clear the cart — the caller (checkout flow) owns that decision.
  Order place(CartState cart, {required String paymentMethod}) {
    final order = Order(
      id: _generateId(),
      items: List.of(cart.items),
      subtotal: cart.subtotal,
      shipping: cart.shipping,
      total: cart.total,
      status: OrderStatus.placed,
      placedAt: DateTime.now(),
      paymentMethod: paymentMethod,
    );
    final next = [order, ...state.orders];
    emit(OrdersState(orders: next, status: OrdersStatus.ready));
    _persistence.writeOrders(next);
    return order;
  }

  /// Advance an active order one step: placed → shipped → delivered.
  /// No-op for completed or cancelled orders.
  void advance(String orderId) {
    final updated = state.orders.map((o) {
      if (o.id != orderId) return o;
      return switch (o.status) {
        OrderStatus.placed => o.copyWith(status: OrderStatus.shipped),
        OrderStatus.shipped => o.copyWith(status: OrderStatus.delivered),
        _ => o,
      };
    }).toList();
    emit(OrdersState(orders: updated, status: OrdersStatus.ready));
    _persistence.writeOrders(updated);
  }
}
