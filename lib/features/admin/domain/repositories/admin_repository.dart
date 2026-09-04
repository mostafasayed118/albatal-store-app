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

  // ─── Catalog Management (T1) ─────────────────────────────

  /// Create or update a product. Returns the product id.
  Future<String> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    required String categoryId,
    required double basePrice,
    required bool isActive,
  });

  /// Create or update a variant for a product. Returns the variant id.
  Future<String> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  });

  /// Replace all images for a product with the given storage paths.
  Future<void> adminSetProductImages(
      String productId, List<String> storagePaths);

  /// Get currently active flash sales (window filter).
  Future<List<Map<String, dynamic>>> getActiveFlashSales();

  /// Get all variants for [productId], ordered by size.
  Future<List<Map<String, dynamic>>> getVariants(String productId);

  /// Get ordered storage paths for a product's images.
  Future<List<String>> getProductImagePaths(String productId);
}
