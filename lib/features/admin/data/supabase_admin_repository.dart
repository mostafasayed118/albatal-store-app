import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
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
import 'admin_mappers.dart';

/// Supabase-backed implementation of [AdminRepository].
///
/// The only place in the admin feature that knows about Supabase. Raw
/// rows/RPC payloads are mapped to typed entities by [AdminMappers] and
/// every failure is returned as `Result.failure` — no exceptions cross
/// the repository boundary.
final class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      // Exception) that must never escape the repository boundary.
      Log.w('Admin permission probe failed; denying admin: $e',
          category: LogCategory.auth);
      return false;
    }
  }

  // ─── Order Fulfillment ──────────────────────────────────

  @override
  Future<Result<List<AdminOrder>>> getAllOrders({
    AdminOrderStatus? status,
    int limit = 50,
  }) async {
    try {
      final query = _client.from('orders').select('*, profiles(full_name)');
      final filtered =
          status != null ? query.eq('status', status.dbValue) : query;
      final rows =
          await filtered.order('placed_at', ascending: false).limit(limit);
      return Success((rows as List)
          .whereType<Map<String, dynamic>>()
          // Rows without a string id cannot be navigated to; skip them.
          .where((r) => r['id'] is String)
          .map(AdminMappers.orderFromRow)
          .toList());
    } catch (e) {
      return Failure(AppError('Failed to load orders', cause: e));
    }
  }

  @override
  Future<Result<AdminOrder?>> getOrderDetails(String orderId) async {
    try {
      final row = await _client
          .from('orders')
          .select('*, order_items(*), profiles(id, full_name, membership_tier)')
          .eq('id', orderId)
          .maybeSingle();
      if (row == null) return const Success(null);
      return Success(AdminMappers.orderDetailFromRow(row));
    } catch (e) {
      return Failure(AppError('Failed to load order', cause: e));
    }
  }

  @override
  Future<Result<void>> updateOrderStatus(
    String orderId,
    AdminOrderStatus status, {
    String? trackingNumber,
  }) async {
    if (status == AdminOrderStatus.unknown) {
      return const Failure(AppError('Unknown order status'));
    }
    try {
      await _client.rpc('update_order_status', params: {
        'p_order_id': orderId,
        'p_new_status': status.dbValue,
        'p_tracking_number': trackingNumber,
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to update order status', cause: e));
    }
  }

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  }) async {
    try {
      final response = await _client
          .rpc('get_low_stock_products', params: {'p_threshold': threshold});
      return Success(
          AdminMappers.lowStockVariantsFromRows(response as List<dynamic>));
    } catch (e) {
      return Failure(AppError('Failed to load low stock products', cause: e));
    }
  }

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) async {
    try {
      // Read-only dashboard aggregation (#12): a single bounded select
      // over existing orders rows with the joined line-item columns the
      // detail query already uses. Client-side aggregation keeps the
      // schema untouched; the limit keeps a burst of orders from
      // stalling the dashboard (same bounded-read discipline as
      // [getAllProducts]).
      final now = DateTime.now();
      final firstDay = DateTime.utc(now.year, now.month, now.day).subtract(
        Duration(days: (days < 1 ? 1 : days) - 1),
      );
      final rows = await _client
          .from('orders')
          .select('id, status, total, placed_at, '
              'order_items(product_name, quantity)')
          .gte('placed_at', firstDay.toIso8601String())
          .order('placed_at')
          .limit(1000);
      return Success(AdminMappers.salesOverviewFromRows(
        rows as List<dynamic>,
        days: days,
        now: now,
      ));
    } catch (e) {
      return Failure(AppError('Failed to load sales overview', cause: e));
    }
  }

  // ─── Variant Management ─────────────────────────────────

  @override
  Future<Result<void>> updateStock(String variantId, int newStock) async {
    try {
      await _client
          .from('product_variants')
          .update({'stock': newStock}).eq('id', variantId);
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to update stock', cause: e));
    }
  }

  // ─── Catalog Management (T1) ─────────────────────────────

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async {
    try {
      // Bounded like the storefront fetchProducts(limit: 100) so a large
      // products table cannot stall the admin list: first 100 rows by
      // name via an explicit range page (audit residual P4).
      final rows = await _client
          .from('products')
          .select('id, name, slug, description, composition, category_id, '
              'base_price, is_active, categories(name)')
          .order('name')
          .limit(100)
          .range(0, 99);
      return Success(AdminMappers.productsFromRows(rows as List<dynamic>));
    } catch (e) {
      return Failure(AppError('Failed to load products', cause: e));
    }
  }

  @override
  Future<Result<AdminProduct?>> getProductById(String productId) async {
    try {
      final rows = await _client
          .from('products')
          .select('id, name, slug, description, composition, category_id, '
              'base_price, is_active, categories(name)')
          .eq('id', productId)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isEmpty) return const Success(null);
      return Success(AdminMappers.productsFromRows(list).first);
    } catch (e) {
      return Failure(AppError('Failed to load product', cause: e));
    }
  }

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select('id, name, is_active')
          .order('sort_order');
      return Success(AdminMappers.categoriesFromRows(rows as List<dynamic>));
    } catch (e) {
      return Failure(AppError('Failed to load categories', cause: e));
    }
  }

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
  }) async {
    try {
      // [basePrice] arrives as minor units (the admin form converts EGP
      // text via [Money.tryParseMajor]); the RPC writes into
      // `products.base_price` INTEGER (migration 001), so send an exact
      // int, not a double the DB would have to coerce (audit 2026-09-14).
      final res = await _client.rpc('admin_upsert_product', params: {
        'p_id': id,
        'p_name': name,
        'p_slug': slug,
        'p_description': description,
        'p_composition': composition,
        'p_category_id': categoryId,
        'p_base_price': basePrice.round(),
        'p_is_active': isActive,
        // §10 fabric attributes: only sent when set — the pre-051 RPC
        // rejects unknown named parameters.
        if (care != null) 'p_care': care,
        if (origin != null) 'p_origin': origin,
        if (widthCm != null) 'p_width_cm': widthCm,
        if (gsm != null) 'p_gsm': gsm,
        if (sellByLength != null) 'p_sell_by_length': sellByLength,
        if (minCutMeters != null) 'p_min_cut_meters': minCutMeters,
      });
      if (res is! String || res.isEmpty) {
        return const Failure(AppError('Failed to save product'));
      }
      return Success(res);
    } catch (e) {
      return Failure(AppError('Failed to save product', cause: e));
    }
  }

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) async {
    try {
      // Same minor-unit contract as [adminUpsertProduct]:
      // `product_variants.price_override` is INTEGER (migration 001).
      final res = await _client.rpc('admin_upsert_variant', params: {
        'p_product_id': productId,
        'p_size': size,
        'p_color': color,
        'p_stock': stock,
        'p_price_override': priceOverride?.round(),
      });
      if (res is! String || res.isEmpty) {
        return const Failure(AppError('Failed to save variant'));
      }
      return Success(res);
    } catch (e) {
      return Failure(AppError('Failed to save variant', cause: e));
    }
  }

  @override
  Future<Result<void>> adminSetProductImages(
      String productId, List<String> storagePaths) async {
    try {
      await _client.rpc('admin_set_product_images', params: {
        'p_product_id': productId,
        'p_paths': storagePaths,
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to save images', cause: e));
    }
  }

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) async {
    try {
      final res = await _client
          .from('product_variants')
          .select()
          .eq('product_id', productId)
          .order('size');
      return Success(AdminMappers.variantsFromRows(res as List));
    } catch (e) {
      return Failure(AppError('Failed to load variants', cause: e));
    }
  }

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) async {
    try {
      final res = await _client
          .from('product_images')
          .select('storage_path')
          .eq('product_id', productId)
          .order('sort_order');
      return Success(AdminMappers.imagePathsFromRows(res as List));
    } catch (e) {
      return Failure(AppError('Failed to load images', cause: e));
    }
  }

  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) async {
    try {
      await _client.rpc('admin_set_membership_tier', params: {
        'p_profile_id': profileId,
        'p_tier': tier,
      });
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to update membership tier', cause: e));
    }
  }

  // ─── Coupons (feature-batch §8) ─────────────────────────

  @override
  Future<Result<List<AdminCoupon>>> fetchCoupons() async {
    try {
      final rows = await _client
          .from('coupons')
          .select('id, code, discount_minor, description, active')
          .order('created_at', ascending: false);
      final list = rows as List<dynamic>;
      return Success(
        list.map((row) => _couponFromRow(row as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      return Failure(AppError('Failed to fetch coupons', cause: e));
    }
  }

  @override
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  }) async {
    try {
      final row = await _client
          .from('coupons')
          .upsert({
            'code': code.trim().toUpperCase(),
            'discount_minor': discountMinor,
            if (description != null && description.isNotEmpty)
              'description': description,
          })
          .select('id, code, discount_minor, description, active')
          .single();
      return Success(_couponFromRow(row));
    } catch (e) {
      return Failure(AppError('Failed to create coupon', cause: e));
    }
  }

  @override
  Future<Result<void>> setCouponActive(String id, bool active) async {
    try {
      await _client.from('coupons').update({'active': active}).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to update coupon', cause: e));
    }
  }

  // ─── Customers (feature-batch §14) ──────────────────────

  @override
  Future<Result<List<AdminCustomer>>> fetchCustomers() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, email, membership_tier')
          .order('created_at', ascending: false)
          .limit(500);
      final list = rows as List<dynamic>;
      return Success(list
          .map((row) => row as Map<String, dynamic>)
          .map((row) => AdminCustomer(
                id: row['id'] as String? ?? '',
                name: row['full_name'] as String? ?? '',
                email: row['email'] as String? ?? '',
                tier: row['membership_tier'] as String? ?? 'standard',
                isBlocked:
                    false, // no suspension flag in profiles (§14 read-only)
              ))
          .where((c) => c.id.isNotEmpty)
          .toList());
    } catch (e) {
      return Failure(AppError('Failed to fetch customers', cause: e));
    }
  }

  // ─── Review moderation (feature-batch §9) ───────────────

  @override
  Future<Result<List<({String id, String product, String text, int rating})>>>
      fetchPendingReviews() async {
    try {
      final rows = await _client
          .from('product_reviews')
          .select('id, product_id, text, rating')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(100);
      final list = rows as List<dynamic>;
      return Success(list
          .map((row) => row as Map<String, dynamic>)
          .map((row) => (
                id: row['id'] as String,
                product: row['product_id'] as String,
                text: row['text'] as String? ?? '',
                rating: (row['rating'] as num?)?.toInt() ?? 0,
              ))
          .toList());
    } catch (e) {
      return Failure(AppError('Failed to fetch pending reviews', cause: e));
    }
  }

  @override
  Future<Result<void>> setReviewStatus(String id, String status) async {
    try {
      await _client
          .from('product_reviews')
          .update({'status': status}).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to update review status', cause: e));
    }
  }
}

AdminCoupon _couponFromRow(Map<String, dynamic> row) => AdminCoupon(
      id: row['id'] as String,
      code: (row['code'] as String?)?.toUpperCase() ?? '',
      discountMinor: (row['discount_minor'] as num?)?.toInt() ?? 0,
      active: row['active'] as bool? ?? false,
      description: row['description'] as String?,
    );
