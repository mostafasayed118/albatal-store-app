import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/admin_order.dart';
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
}
