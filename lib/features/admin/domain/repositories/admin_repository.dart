/// Admin operations for product, order, and fulfillment management.
///
/// Domain port for the admin feature. The data layer implements this
/// against Supabase (see [SupabaseAdminRepository]); the presentation
/// layer (AdminCubit) only depends on this interface, so the backing
/// service can be swapped or faked in tests without touching the UI.
///
/// Responses are still `Map<String, dynamic>` to match the Supabase
/// join/RPC shapes the admin pages already consume. Typing these into
/// dedicated entities is a future refactor — the priority here is
/// establishing the domain boundary so the cubit no longer reaches
/// across layers into a shared service.
abstract interface class AdminRepository {
  /// Check if the current user is an admin.
  Future<bool> isCurrentUserAdmin();

  // ─── Order Fulfillment ──────────────────────────────────

  /// Get all orders with customer info, optionally filtered by status.
  Future<List<Map<String, dynamic>>> getAllOrders({
    String? status,
    int limit = 50,
  });

  /// Get order details with items.
  Future<Map<String, dynamic>?> getOrderDetails(String orderId);

  /// Update order status with optional tracking number.
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
  });

  /// Get low stock products below [threshold].
  Future<List<Map<String, dynamic>>> getLowStockProducts({
    int threshold = 5,
  });

  // ─── Variant Management ─────────────────────────────────

  /// Update variant stock by variant id.
  Future<void> updateStock(String variantId, int newStock);
}
