import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/entities/low_stock_variant.dart';
import '../../domain/repositories/admin_repository.dart';

// ─── States ────────────────────────────────────────────────

enum AdminStatus { initial, loading, ready, error }

final class AdminState extends Equatable {
  const AdminState({
    this.status = AdminStatus.initial,
    this.orders = const [],
    this.lowStockProducts = const [],
    this.selectedOrder,
    this.statusFilter,
    this.errorMessage,
  });

  final AdminStatus status;
  final List<AdminOrder> orders;
  final List<LowStockVariant> lowStockProducts;
  final AdminOrder? selectedOrder;

  /// Queue filter. Null shows every order; [AdminOrderStatus.unknown] is
  /// never assigned a filter (see [loadOrders]).
  final AdminOrderStatus? statusFilter;
  final String? errorMessage;

  List<AdminOrder> get filteredOrders {
    final filter = statusFilter;
    if (filter == null) return orders;
    return orders.where((o) => o.status == filter).toList();
  }

  AdminState copyWith({
    AdminStatus? status,
    List<AdminOrder>? orders,
    List<LowStockVariant>? lowStockProducts,
    AdminOrder? selectedOrder,
    AdminOrderStatus? statusFilter,
    String? errorMessage,
    bool clearSelectedOrder = false,
    bool clearStatusFilter = false,
  }) =>
      AdminState(
        status: status ?? this.status,
        orders: orders ?? this.orders,
        lowStockProducts: lowStockProducts ?? this.lowStockProducts,
        selectedOrder:
            clearSelectedOrder ? null : (selectedOrder ?? this.selectedOrder),
        statusFilter:
            clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [
        status,
        orders,
        lowStockProducts,
        selectedOrder,
        statusFilter,
        errorMessage,
      ];
}

// ─── Cubit ─────────────────────────────────────────────────

/// Presentation-layer state machine for the admin screens.
///
/// Consumes `Result` values from [AdminRepository] — errors are
/// translated into user-safe [AdminState.errorMessage] strings here, the
/// single place admin failures become UI state. No exceptions are caught
/// (none escape the repository) and no raw row maps appear in state.
class AdminCubit extends Cubit<AdminState> {
  AdminCubit(this._adminRepository) : super(const AdminState());

  final AdminRepository _adminRepository;

  /// Check if current user is admin.
  Future<void> checkAdmin() async {
    final isAdmin = await _adminRepository.isCurrentUserAdmin();
    if (!isAdmin) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: 'Access denied: admin only',
      ));
    }
  }

  /// Load orders with optional status filter.
  Future<void> loadOrders({AdminOrderStatus? status}) async {
    emit(state.copyWith(
      status: AdminStatus.loading,
      statusFilter: status,
      clearStatusFilter: status == null,
    ));
    final result = await _adminRepository.getAllOrders(status: status);
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: AdminStatus.ready, orders: value));
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Load order details.
  Future<void> loadOrderDetails(String orderId) async {
    emit(state.copyWith(status: AdminStatus.loading));
    final result = await _adminRepository.getOrderDetails(orderId);
    switch (result) {
      case Success(:final value):
        if (value == null) {
          emit(state.copyWith(
            status: AdminStatus.error,
            errorMessage: 'Order not found',
          ));
        } else {
          emit(state.copyWith(
            status: AdminStatus.ready,
            selectedOrder: value,
          ));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Update order status.
  Future<void> updateOrderStatus(
    String orderId,
    AdminOrderStatus status, {
    String? trackingNumber,
  }) async {
    final result = await _adminRepository.updateOrderStatus(
      orderId,
      status,
      trackingNumber: trackingNumber,
    );
    switch (result) {
      case Success():
        // Reload orders after status update so the queue reflects it.
        await loadOrders(status: state.statusFilter);
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Load low stock products.
  Future<void> loadLowStockProducts({int threshold = 5}) async {
    final result =
        await _adminRepository.getLowStockProducts(threshold: threshold);
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(
          status: AdminStatus.ready,
          lowStockProducts: value,
        ));
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Update variant stock.
  Future<void> updateStock(String variantId, int newStock) async {
    final result = await _adminRepository.updateStock(variantId, newStock);
    switch (result) {
      case Success():
        await loadLowStockProducts();
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
        ));
    }
  }

  /// Clear selected order.
  void clearSelectedOrder() => emit(state.copyWith(clearSelectedOrder: true));

  /// Clear error.
  void clearError() {
    if (state.status == AdminStatus.error) {
      emit(state.copyWith(status: AdminStatus.ready));
    }
  }
}
