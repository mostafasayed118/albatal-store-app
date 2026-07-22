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
}
