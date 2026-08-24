import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/admin_repository.dart';

/// Supabase-backed implementation of [AdminRepository].
///
/// Wraps the Supabase client and translates RPC/table responses into
/// the `Map<String, dynamic>` shape the admin pages already consume.
/// This is the single place that knows about Supabase in the admin
/// feature — the cubit and UI depend only on [AdminRepository].
final class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final response = await _client
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .single();
    return response['is_admin'] as bool? ?? false;
  }

  // ─── Order Fulfillment ──────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getAllOrders({
    String? status,
    int limit = 50,
  }) async {
    final query = _client.from('orders').select('*, profiles(full_name)');
    final filtered = status != null ? query.eq('status', status) : query;
    final result =
        await filtered.order('placed_at', ascending: false).limit(limit);
    return (result as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    final response = await _client
        .from('orders')
        .select('*, order_items(*), profiles(full_name)')
        .eq('id', orderId)
        .single();
    return response;
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
  }) async {
    await _client.rpc('update_order_status', params: {
      'p_order_id': orderId,
      'p_new_status': status,
      'p_tracking_number': trackingNumber,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getLowStockProducts({
    int threshold = 5,
  }) async {
    final response = await _client
        .rpc('get_low_stock_products', params: {'p_threshold': threshold});
    return (response as List).cast<Map<String, dynamic>>();
  }

  // ─── Variant Management ─────────────────────────────────

  @override
  Future<void> updateStock(String variantId, int newStock) async {
    await _client
        .from('product_variants')
        .update({'stock': newStock}).eq('id', variantId);
  }

  // ─── Catalog Management (T1) ─────────────────────────────

  @override
  Future<String> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    required String categoryId,
    required double basePrice,
    required bool isActive,
  }) async {
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
    return res as String;
  }

  @override
  Future<String> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) async {
    final res = await _client.rpc('admin_upsert_variant', params: {
      'p_product_id': productId,
      'p_size': size,
      'p_color': color,
      'p_stock': stock,
      'p_price_override': priceOverride,
    });
    return res as String;
  }

  @override
  Future<void> adminSetProductImages(String productId, List<String> storagePaths) async {
    await _client.rpc('admin_set_product_images', params: {
      'p_product_id': productId,
      'p_paths': storagePaths,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async {
    final res = await _client.rpc('get_active_flash_sales');
    return (res as List).cast<Map<String, dynamic>>();
  }
}
