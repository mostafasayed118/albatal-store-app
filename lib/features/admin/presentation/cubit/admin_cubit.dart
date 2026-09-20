import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure_codes.dart';
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
    this.errorCode,
  });

  final AdminStatus status;
  final List<AdminOrder> orders;
  final List<LowStockVariant> lowStockProducts;
  final AdminOrder? selectedOrder;

  /// Queue filter. Null shows every order; [AdminOrderStatus.unknown] is
  /// never assigned a filter (see [loadOrders]).
  final AdminOrderStatus? statusFilter;
  final String? errorMessage;

  /// App-authored failure code; drives localization at the render site.
  final String? errorCode;

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
    String? errorCode,
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
        errorCode: errorCode,
      );

  @override
  List<Object?> get props => [
        status,
        orders,
        lowStockProducts,
        selectedOrder,
        statusFilter,
        errorMessage,
        errorCode,
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
    if (isClosed) return;
    if (!isAdmin) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: 'Access denied: admin only',
        errorCode: kAdminAccessDenied,
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
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(status: AdminStatus.ready, orders: value));
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  /// Load order details.
  Future<void> loadOrderDetails(String orderId) async {
    emit(state.copyWith(status: AdminStatus.loading));
    final result = await _adminRepository.getOrderDetails(orderId);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        if (value == null) {
          emit(state.copyWith(
            status: AdminStatus.error,
            errorMessage: 'Order not found',
            errorCode: kAdminOrderNotFound,
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
          errorCode: error.code,
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
    if (isClosed) return;
    switch (result) {
      case Success():
        // Reload orders after status update so the queue reflects it.
        await loadOrders(status: state.statusFilter);
        if (isClosed) return;
        // Refresh the open detail from the reloaded queue: without this,
        // the status card kept showing the pre-transition status until
        // the admin left and re-entered the page.
        if (state.selectedOrder?.id == orderId) {
          final updated = state.orders.where((o) => o.id == orderId).toList();
          emit(state.copyWith(
            selectedOrder: updated.isNotEmpty ? updated.first : null,
            clearSelectedOrder: updated.isEmpty,
          ));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
        ));
    }
  }

  /// Load low stock products.
  Future<void> loadLowStockProducts({int threshold = 5}) async {
    final result =
        await _adminRepository.getLowStockProducts(threshold: threshold);
    if (isClosed) return;
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
          errorCode: error.code,
        ));
    }
  }

  /// Update variant stock.
  Future<void> updateStock(String variantId, int newStock) async {
    final result = await _adminRepository.updateStock(variantId, newStock);
    if (isClosed) return;
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

  /// Set a customer's membership tier via the admin-gated RPC
  /// (migration 046). On success the open order's customer card reflects
  /// the new tier immediately — the repository confirmed the write before
  /// this emits, so pages can verify acks against state like every other
  /// admin transition. Failures surface through the shared error channel.
  Future<void> setMembershipTier(String profileId, String tier) async {
    final result = await _adminRepository.setMembershipTier(profileId, tier);
    if (isClosed) return;
    switch (result) {
      case Success():
        final selected = state.selectedOrder;
        if (selected != null && selected.customerId == profileId) {
          emit(state.copyWith(
            selectedOrder: selected.copyWith(customerTier: tier),
          ));
        }
      case Failure(:final error):
        emit(state.copyWith(
          status: AdminStatus.error,
          errorMessage: error.message,
          errorCode: error.code,
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
