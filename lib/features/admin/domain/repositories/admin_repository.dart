import '../../../../core/error/result.dart';
import '../entities/admin_catalog.dart';
import '../entities/admin_order.dart';
import '../entities/admin_variant.dart';
import '../entities/low_stock_variant.dart';

/// Admin operations for order-queue and inventory management.
///
/// Domain port for the admin feature. The data layer implements this
/// against Supabase (see [SupabaseAdminRepository]); the presentation
/// layer (AdminCubit) depends only on this interface and on the typed
/// entities, never on `Map<String, dynamic>` rows or the Supabase SDK.
///
/// All reads return [Result] so failures are values handled at the
/// cubit boundary instead of thrown exceptions crossing layers.
abstract interface class AdminRepository {
  /// Check if the current user is an admin.
  Future<bool> isCurrentUserAdmin();

  // ─── Order Fulfillment ──────────────────────────────────

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

  /// Get low-stock variants below [threshold].
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  });

  // ─── Variant Management ─────────────────────────────────

  /// Update variant stock by variant id.
  Future<Result<void>> updateStock(String variantId, int newStock);

  // ─── Catalog Management (T1) ─────────────────────────────

  /// Create or update a product. Returns the product id.
  Future<Result<String>> adminUpsertProduct({
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
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  });

  /// Replace all images for a product with the given storage paths.
  Future<Result<void>> adminSetProductImages(
      String productId, List<String> storagePaths);

  /// Get all variants for [productId], ordered by size.
  Future<Result<List<AdminVariant>>> getVariants(String productId);

  /// Get ordered storage paths for a product's images.
  Future<Result<List<String>>> getProductImagePaths(String productId);

  /// Get every product for the catalog management list — including
  /// inactive rows, which are exactly what an admin needs to see and
  /// un-hide. Rows carry the joined category name for display.
  Future<Result<List<AdminProduct>>> getAllProducts();

  /// Get every category for the catalog management list (read-only
  /// until a category write RPC exists).
  Future<Result<List<AdminCategory>>> getAllCategories();

  /// Set a customer's membership tier via the admin-gated RPC
  /// (migration 046). The tier drives the Premium badge customers see.
  Future<Result<void>> setMembershipTier(String profileId, String tier);
}
