import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/services/logger.dart';
import '../domain/entities/admin_catalog.dart';
import '../domain/entities/admin_coupon.dart';
import '../domain/entities/admin_customer.dart';
import '../domain/entities/admin_order.dart';
import '../domain/entities/admin_sales.dart';
import '../domain/entities/admin_variant.dart';
import '../domain/entities/low_stock_variant.dart';
import '../domain/repositories/admin_repository.dart';
import 'admin_catalog_store.dart';
import 'admin_coupons_store.dart';
import 'admin_customers_store.dart';
import 'admin_orders_store.dart';
import 'admin_reviews_store.dart';
import 'admin_sales_store.dart';

export 'admin_customer_search.dart';

/// Supabase-backed implementation of [AdminRepository].
///
/// A thin facade: the only place in the admin feature that knows about
/// Supabase construction. One port-aligned worker per domain
/// ([SupabaseAdminOrders], [SupabaseAdminSales], [SupabaseAdminCatalog],
/// [SupabaseAdminCoupons], [SupabaseAdminCustomers], [SupabaseAdminReviews])
/// owns that domain's queries — every failure is returned as
/// `Result.failure`, no exceptions cross the repository boundary.
final class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({required SupabaseClient client})
      : _client = client,
        _orders = SupabaseAdminOrders(client: client),
        _sales = SupabaseAdminSales(client: client),
        _catalog = SupabaseAdminCatalog(client: client),
        _coupons = SupabaseAdminCoupons(client: client),
        _customers = SupabaseAdminCustomers(client: client),
        _reviews = SupabaseAdminReviews(client: client);

  final SupabaseClient _client;
  final SupabaseAdminOrders _orders;
  final SupabaseAdminSales _sales;
  final SupabaseAdminCatalog _catalog;
  final SupabaseAdminCoupons _coupons;
  final SupabaseAdminCustomers _customers;
  final SupabaseAdminReviews _reviews;

  @override
  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final response = await _client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();
      return response['is_admin'] as bool? ?? false;
    } catch (e) {
      // A failed permission probe must not grant admin. Catches broadly
      // because malformed payloads raise TypeError (an Error, not an
      // Exception) that must never escape the repository boundary. Also why
      // this stays a hand-written `try`/`catch` — it answers with a bool
      // rather than a `Result`, and it logs before denying.
      // Logged via error: (never interpolated — probe payloads can carry
      // PII; audit 2026-09-14 P0-5).
      Log.w('Admin permission probe failed; denying admin.',
          category: LogCategory.auth, error: e);
      return false;
    }
  }

  // ─── Order Fulfillment ──────────────────────────────────

  @override
  Future<Result<List<AdminOrder>>> getAllOrders({
    AdminOrderStatus? status,
    int limit = 50,
  }) =>
      _orders.getAllOrders(status: status, limit: limit);

  @override
  Future<Result<AdminOrder?>> getOrderDetails(String orderId) =>
      _orders.getOrderDetails(orderId);

  @override
  Future<Result<void>> updateOrderStatus(
    String orderId,
    AdminOrderStatus status, {
    String? trackingNumber,
  }) =>
      _orders.updateOrderStatus(
        orderId,
        status,
        trackingNumber: trackingNumber,
      );

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  }) =>
      _sales.getLowStockProducts(threshold: threshold);

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) =>
      _sales.getSalesOverview(days: days);

  // ─── Variant Management ─────────────────────────────────

  @override
  Future<Result<void>> updateStock(String variantId, int newStock) =>
      _catalog.updateStock(variantId, newStock);

  // ─── Catalog Management (T1) ─────────────────────────────

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() =>
      _catalog.getAllProducts();

  @override
  Future<Result<AdminProduct?>> getProductById(String productId) =>
      _catalog.getProductById(productId);

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() =>
      _catalog.getAllCategories();

  @override
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
    required Money basePrice,
    required bool isActive,
  }) =>
      _catalog.adminUpsertProduct(
        id: id,
        name: name,
        slug: slug,
        description: description,
        composition: composition,
        care: care,
        origin: origin,
        widthCm: widthCm,
        gsm: gsm,
        sellByLength: sellByLength,
        minCutMeters: minCutMeters,
        categoryId: categoryId,
        basePrice: basePrice,
        isActive: isActive,
      );

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    Money? priceOverride,
  }) =>
      _catalog.adminUpsertVariant(
        productId: productId,
        size: size,
        color: color,
        stock: stock,
        priceOverride: priceOverride,
      );

  @override
  Future<Result<void>> adminSetProductImages(
          String productId, List<String> storagePaths) =>
      _catalog.adminSetProductImages(productId, storagePaths);

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) =>
      _catalog.getVariants(productId);

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) =>
      _catalog.getProductImagePaths(productId);

  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) =>
      _customers.setMembershipTier(profileId, tier);

  // ─── Coupons (feature-batch §8) ─────────────────────────

  @override
  Future<Result<List<AdminCoupon>>> fetchCoupons() => _coupons.fetchCoupons();

  @override
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) =>
      _coupons.createCoupon(
        code: code,
        discountMinor: discountMinor,
        description: description,
      );

  @override
  Future<Result<void>> setCouponActive(String id, bool active) =>
      _coupons.setCouponActive(id, active);

  // ─── Customers (feature-batch §14) ─────────────────────

  @override
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
  }) =>
      _customers.fetchCustomers(query: query, cursor: cursor, limit: limit);

  // ─── Review moderation (feature-batch §9) ───────────────

  @override
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews() => _reviews.fetchPendingReviews();

  @override
  Future<Result<void>> setReviewStatus(String id, String status) =>
      _reviews.setReviewStatus(id, status);
}
