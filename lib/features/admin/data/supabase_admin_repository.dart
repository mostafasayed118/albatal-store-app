import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'supabase_admin_catalog_repository.dart';
import 'supabase_admin_coupons_repository.dart';
import 'supabase_admin_customers_repository.dart';
import 'supabase_admin_orders_repository.dart';
import 'supabase_admin_reviews_repository.dart';
import 'supabase_admin_sales_repository.dart';

/// Supabase-backed implementation of [AdminRepository] — the multi-concern
/// facade that multi-concern consumers ([AdminCubit], the admin pages)
/// still depend on.
///
/// Audit 2026-09-21, P1: the former 824-line god-class is fully split into
/// six per-port implementations — orders, sales, catalog, customers,
/// coupons and reviews — each in its own file, each testable against its
/// narrow port. This class is now pure composition + delegation: it holds
/// no business logic of its own (the admin permission probe below is the
/// one exception, being the facade's only non-port method), so a change to
/// one concern's data access can never touch another's.
///
/// Consumers that need only one concern should depend on the narrow port
/// ([AdminOrdersPort], [AdminCatalogPort], …), not on this class.
final class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({required SupabaseClient client})
      : _client = client,
        _orders = SupabaseAdminOrdersRepository(client: client),
        _sales = SupabaseAdminSalesRepository(client: client),
        _catalog = SupabaseAdminCatalogRepository(client: client),
        _customers = SupabaseAdminCustomersRepository(client: client),
        _coupons = SupabaseAdminCouponsRepository(client: client),
        _reviews = SupabaseAdminReviewsRepository(client: client);

  /// Kept on the facade for the permission probe below — the one call that
  /// spans no single concern (auth + profiles).
  final SupabaseClient _client;

  final SupabaseAdminOrdersRepository _orders;
  final SupabaseAdminSalesRepository _sales;
  final SupabaseAdminCatalogRepository _catalog;
  final SupabaseAdminCustomersRepository _customers;
  final SupabaseAdminCouponsRepository _coupons;
  final SupabaseAdminReviewsRepository _reviews;

  // ─── Admin gate (facade-only method: no narrow port owns it) ──────────

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

  // ─── Orders (AdminOrdersPort) ────────────────────────────

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
      _orders.updateOrderStatus(orderId, status,
          trackingNumber: trackingNumber);

  // ─── Sales (AdminSalesPort) ──────────────────────────────

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) =>
      _sales.getSalesOverview(days: days);

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  }) =>
      _sales.getLowStockProducts(threshold: threshold);

  // ─── Catalog (AdminCatalogPort) ──────────────────────────

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
    required double basePrice,
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
    double? priceOverride,
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
  Future<Result<void>> updateStock(String variantId, int newStock) =>
      _catalog.updateStock(variantId, newStock);

  // ─── Customers (AdminCustomersPort) ──────────────────────

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

  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) =>
      _customers.setMembershipTier(profileId, tier);

  // ─── Coupons (AdminCouponsPort) ──────────────────────────

  @override
  Future<Result<List<AdminCoupon>>> fetchCoupons() => _coupons.fetchCoupons();

  @override
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) =>
      _coupons.createCoupon(
          code: code, discountMinor: discountMinor, description: description);

  @override
  Future<Result<void>> setCouponActive(String id, bool active) =>
      _coupons.setCouponActive(id, active);

  // ─── Reviews (AdminReviewsPort) ──────────────────────────

  @override
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews() => _reviews.fetchPendingReviews();

  @override
  Future<Result<void>> setReviewStatus(String id, String status) =>
      _reviews.setReviewStatus(id, status);
}
