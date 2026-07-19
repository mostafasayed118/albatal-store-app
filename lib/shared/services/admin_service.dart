import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin operations for product, order, and fulfillment management.
class AdminService {
  AdminService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Check if the current user is an admin.
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

  /// Get all orders with customer info.
  Future<List<Map<String, dynamic>>> getAllOrders({
    String? status,
    int limit = 50,
  }) async {
    final query = _client.from('orders').select('*, profiles(full_name)');

    final filtered = status != null
        ? query.eq('status', status)
        : query;

    final result = await filtered
        .order('placed_at', ascending: false)
        .limit(limit);

    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Get order details with items.
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    final response = await _client
        .from('orders')
        .select('*, order_items(*), profiles(full_name)')
        .eq('id', orderId)
        .single();
    return response;
  }

  /// Update order status with validation.
  Future<void> updateOrderStatus(String orderId, String status,
      {String? trackingNumber}) async {
    await _client.rpc('update_order_status', params: {
      'p_order_id': orderId,
      'p_new_status': status,
      'p_tracking_number': trackingNumber,
    });
  }

  /// Get low stock products.
  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 5}) async {
    final response = await _client
        .rpc('get_low_stock_products', params: {'p_threshold': threshold});
    return (response as List).cast<Map<String, dynamic>>();
  }

  // ─── Product Management ─────────────────────────────────

  Future<Map<String, dynamic>?> createProduct({
    required String name,
    required String categoryId,
    required int basePrice,
    String? description,
  }) async {
    final response = await _client.from('products').insert({
      'name': name,
      'slug': name.toLowerCase().replaceAll(' ', '-'),
      'category_id': categoryId,
      'base_price': basePrice,
      'description': description,
    }).select().single();
    return response;
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> updates) async {
    await _client.from('products').update(updates).eq('id', productId);
  }

  Future<void> toggleProductActive(String productId, bool isActive) async {
    await _client
        .from('products')
        .update({'is_active': isActive}).eq('id', productId);
  }

  // ─── Variant Management ─────────────────────────────────

  Future<Map<String, dynamic>?> addVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
  }) async {
    final response = await _client.from('product_variants').insert({
      'product_id': productId,
      'size': size,
      'color': color,
      'stock': stock,
    }).select().single();
    return response;
  }

  Future<void> updateStock(String variantId, int newStock) async {
    await _client
        .from('product_variants')
        .update({'stock': newStock}).eq('id', variantId);
  }

  // ─── Category Management ────────────────────────────────

  Future<Map<String, dynamic>?> createCategory({
    required String name,
    required String slug,
  }) async {
    final response = await _client.from('categories').insert({
      'name': name,
      'slug': slug,
    }).select().single();
    return response;
  }
}
