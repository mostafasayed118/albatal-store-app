import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/admin_order.dart';
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
      final rows = await filtered
          .order('placed_at', ascending: false)
          .limit(limit);
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
          .select('*, order_items(*), profiles(full_name)')
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
  Future<Result<String>> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    required String categoryId,
    required double basePrice,
    required bool isActive,
  }) async {
    try {
      final res = await _client.rpc('admin_upsert_product', params: {
        'p_id': id,
        'p_name': name,
        'p_slug': slug,
        'p_description': description,
        'p_composition': composition,
        'p_category_id': categoryId,
        'p_base_price': basePrice,
        'p_is_active': isActive,
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
      final res = await _client.rpc('admin_upsert_variant', params: {
        'p_product_id': productId,
        'p_size': size,
        'p_color': color,
        'p_stock': stock,
        'p_price_override': priceOverride,
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
  Future<Result<List<Map<String, dynamic>>>> getActiveFlashSales() async {
    try {
      final res = await _client.rpc('get_active_flash_sales');
      return Success(AdminMappers.flashSalesFromRows(res as List));
      // A failed flash-sale fetch is non-critical; still surfaced as a
      // failure Result so callers can decide (the catalog cubit swallows).
    } catch (e) {
      return Failure(AppError('Failed to load flash sales', cause: e));
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
}
