import '../../../../core/error/result.dart';
import '../entities/admin_order.dart';

/// Narrow port for the admin order-fulfillment queue (ISP).
///
/// Split out of [AdminRepository] (audit): order-queue consumers used 2–3
/// methods of a ~20-method interface spanning 7 concerns. Cubits that only
/// drive the queue depend on this instead of the full facade; the facade
/// itself still extends it, so existing implementations keep working.
abstract interface class AdminOrdersPort {
  /// Get orders for the fulfillment queue, newest first.
  ///
  /// [status] filters by DB status name when provided. Rows are mapped
  /// to [AdminOrder] queue models (no line items — use [getOrderDetails]
  /// for the itemized view).
  Future<Result<List<AdminOrder>>> getAllOrders({
    AdminOrderStatus? status,
    int limit = 50,
  });

  /// Get one order with its line items, or null when not found.
  Future<Result<AdminOrder?>> getOrderDetails(String orderId);

  /// Update order status with optional tracking number.
  ///
  /// [status] must be a real `order_status` value; [AdminOrderStatus.unknown]
  /// is rejected as a [Failure] before any network call.
  Future<Result<void>> updateOrderStatus(
    String orderId,
    AdminOrderStatus status, {
    String? trackingNumber,
  });
}
