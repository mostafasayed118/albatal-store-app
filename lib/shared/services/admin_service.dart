import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin operations for product and order management.
class AdminService {
  AdminService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _client
        .from('orders')
        .update({'status': status}).eq('id', orderId);
  }

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
