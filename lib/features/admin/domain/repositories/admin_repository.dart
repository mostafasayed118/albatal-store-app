import '../../../../core/error/result.dart';
import '../entities/admin_catalog.dart';
import '../entities/admin_coupon.dart';
import '../entities/admin_customer.dart';
import '../entities/admin_order.dart';
import '../entities/admin_sales.dart';
import '../entities/admin_variant.dart';
import '../entities/low_stock_variant.dart';

/// Rows per customer-directory page when a caller does not choose a size.
///
/// Shared by the repository default and the directory cubit so the paging
/// contract has a single number: the cubit decides *when* to ask for the next
/// page, this decides how much arrives.
const defaultCustomersPageSize = 50;

/// Where a reader has got to in the newest-first customer directory: the
/// `(createdAt, id)` of the last row it has seen.
///
/// Shared between the repository that hands one back and the cubit that hands
/// it straight back in when asking for more, so it lives on the port rather
/// than in the data layer. [createdAt] is canonical UTC ISO-8601 — the form
/// the server compares against `timestamptz` directly.
typedef CustomerCursor = ({String createdAt, String id});

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

  // ─── Coupons (feature-batch §8) ─────────────────────────

  /// All coupons, newest first (review-gated `coupons` table, 049).
  Future<Result<List<AdminCoupon>>> fetchCoupons();

  /// Creates or updates a coupon by code (server uppercases codes).
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  });

  /// Enables/disables a coupon without deleting it.
  Future<Result<void>> setCouponActive(String id, bool active);

  // ─── Customers (feature-batch §14) ──────────────────────

  /// One bounded page of customer profiles, newest first (admin-only by
  /// RLS), plus what a caller needs to reach the next page.
  ///
  /// [query] is applied on the **server** — a case-insensitive substring of
  /// the name — so a search covers the whole table rather than only the pages
  /// already loaded. Blank means no filter.
  ///
  /// Paging is **keyset**: [cursor] names the last row already seen and the
  /// server answers with only what follows it in `(createdAt DESC, id DESC)`
  /// order. Reads stay bounded by [limit] on purpose (audit query
  /// discipline). Before any of this the directory was a single `.limit(500)`
  /// with no way past it, so the 501st customer was unreachable and nothing
  /// said so.
  ///
  /// [nextCursor] is null exactly when the page just read is the last one, so
  /// a caller never has to guess — and never has to issue an empty request to
  /// find out.
  ///
  /// [total] is the exact number of rows matching [query], reported **only on
  /// the first page** (a null [cursor]). A cursor narrows the filter the count
  /// is taken over, so on a continuation page the server would be counting the
  /// rows *remaining* rather than the rows that match; publishing that would
  /// make the directory's "showing X of Y" shrink as the admin scrolled.
  /// Callers keep the first page's total — see `AdminCustomersCubit`, which
  /// does exactly that.
  Future<
      Result<
          ({
            List<AdminCustomer> customers,
            int? total,
            CustomerCursor? nextCursor,
          })>> fetchCustomers({
    String? query,
    CustomerCursor? cursor,
    int limit = defaultCustomersPageSize,
  });

  // ─── Review moderation (feature-batch §9) ───────────────

  /// Pending review rows: (id, product, text, rating).
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews();

  /// Sets a review's moderation status (`approved` / `rejected`).
  Future<Result<void>> setReviewStatus(String id, String status);

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

  // ─── Sales Dashboard (#12, read-only) ────────────────────

  /// Aggregated sales overview for the last [days] days.
  ///
  /// Purely read-only: one bounded select over existing `orders` rows
  /// (with joined `order_items(product_name, quantity)`), aggregated
  /// client-side — no schema change and no write. The result carries a
  /// zero-filled revenue-per-day timeline, top-5 products by units
  /// sold, and order counts by status within the same window.
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14});

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
    String? care,
    String? origin,
    int? widthCm,
    int? gsm,
    bool? sellByLength,
    double? minCutMeters,
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

  /// Single product for the edit-form prefill — avoids the
  /// fetch-all-and-scan the page previously did (audit 2026-09-13).
  /// Null when the id does not exist.
  Future<Result<AdminProduct?>> getProductById(String productId);

  /// Get every category for the catalog management list (read-only
  /// until a category write RPC exists).
  Future<Result<List<AdminCategory>>> getAllCategories();

  /// Set a customer's membership tier via the admin-gated RPC
  /// (migration 046). The tier drives the Premium badge customers see.
  Future<Result<void>> setMembershipTier(String profileId, String tier);
}
