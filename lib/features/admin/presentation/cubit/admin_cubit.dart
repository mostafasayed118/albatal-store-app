import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

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
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> lowStockProducts;
  final Map<String, dynamic>? selectedOrder;
  final String? statusFilter;
  final String? errorMessage;

  List<Map<String, dynamic>> get filteredOrders {
    if (statusFilter == null) return orders;
    return orders.where((o) => o['status'] == statusFilter).toList();
  }

  AdminState copyWith({
    AdminStatus? status,
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? lowStockProducts,
    Map<String, dynamic>? selectedOrder,
    String? statusFilter,
    String? errorMessage,
    bool clearSelectedOrder = false,
  }) =>
      AdminState(
        status: status ?? this.status,
        orders: orders ?? this.orders,
        lowStockProducts: lowStockProducts ?? this.lowStockProducts,
        selectedOrder:
            clearSelectedOrder ? null : (selectedOrder ?? this.selectedOrder),
        statusFilter: statusFilter ?? this.statusFilter,
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
  Future<void> loadOrders({String? status}) async {
    emit(state.copyWith(status: AdminStatus.loading, statusFilter: status));
    try {
      final orders = await _adminRepository.getAllOrders(status: status);
      emit(state.copyWith(status: AdminStatus.ready, orders: orders));
    } catch (e) {
      emit(state.copyWith(
          status: AdminStatus.error, errorMessage: 'Failed to load orders'));
    }
  }

  /// Load order details.
  Future<void> loadOrderDetails(String orderId) async {
    emit(state.copyWith(status: AdminStatus.loading));
    try {
      final details = await _adminRepository.getOrderDetails(orderId);
      emit(state.copyWith(
          status: AdminStatus.ready, selectedOrder: details));
    } catch (e) {
      emit(state.copyWith(
          status: AdminStatus.error, errorMessage: 'Failed to load order'));
    }
  }

  /// Update order status.
  Future<void> updateOrderStatus(String orderId, String status,
      {String? trackingNumber}) async {
    try {
      await _adminRepository.updateOrderStatus(orderId, status,
          trackingNumber: trackingNumber);
      // Reload orders after status update
      await loadOrders(status: state.statusFilter);
    } catch (e) {
      emit(state.copyWith(
          status: AdminStatus.error, errorMessage: 'Failed to update status'));
    }
  }

  /// Load low stock products.
  Future<void> loadLowStockProducts({int threshold = 5}) async {
    try {
      final products =
          await _adminRepository.getLowStockProducts(threshold: threshold);
      emit(state.copyWith(lowStockProducts: products));
    } catch (e) {
      emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: 'Failed to load low stock products'));
    }
  }

  /// Update variant stock.
  Future<void> updateStock(String variantId, int newStock) async {
    try {
      await _adminRepository.updateStock(variantId, newStock);
      await loadLowStockProducts();
    } catch (e) {
      emit(state.copyWith(
          status: AdminStatus.error, errorMessage: 'Failed to update stock'));
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
