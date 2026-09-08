import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/order.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/orders_repository.dart';

export '../../../../core/entities/order.dart';

enum OrdersStatus { initial, loading, ready, error }

final class OrdersState extends Equatable {
  OrdersState({
    this.orders = const [],
    this.status = OrdersStatus.ready,
    this.errorMessage,
  });

  final List<Order> orders;
  final OrdersStatus status;
  final String? errorMessage;

  /// Lazy storage for the tab views (same pattern as CatalogState's
  /// `_CatalogMemos`): the orders page reads all three tabs per build,
  /// so each O(n) filter + O(k log k) sort runs once per state.
  final _OrdersMemos _m = _OrdersMemos();

  List<Order> get active {
    var cached = _m.active;
    if (cached == null) {
      cached = orders
          .where((o) =>
              o.status == OrderStatus.pending ||
              o.status == OrderStatus.placed ||
              o.status == OrderStatus.processing ||
              o.status == OrderStatus.shipped)
          .toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      _m.active = cached;
    }
    return cached;
  }

  List<Order> get completed {
    var cached = _m.completed;
    if (cached == null) {
      cached = orders
          .where((o) =>
              o.status == OrderStatus.paid || o.status == OrderStatus.delivered)
          .toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      _m.completed = cached;
    }
    return cached;
  }

  List<Order> get cancelled {
    var cached = _m.cancelled;
    if (cached == null) {
      cached = orders
          .where((o) =>
              o.status == OrderStatus.cancelled ||
              o.status == OrderStatus.expired ||
              o.status == OrderStatus.refunded)
          .toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      _m.cancelled = cached;
    }
    return cached;
  }

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

/// Per-state lazy storage for [OrdersState]'s tab views. Mutable by
/// design but never compared in equality.
class _OrdersMemos {
  List<Order>? active;
  List<Order>? completed;
  List<Order>? cancelled;
}

final class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._repository)
      : super(OrdersState(status: OrdersStatus.initial));

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
}
