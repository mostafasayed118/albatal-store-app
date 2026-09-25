import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/admin_order.dart';
import '../domain/repositories/admin_orders_port.dart';
import 'admin_mappers.dart';

/// Order-queue reads and fulfillment writes for [SupabaseAdminRepository].
///
/// Implements [AdminOrdersPort] against Supabase; the facade keeps the
/// `AdminRepository` surface and delegates here unchanged.
final class SupabaseAdminOrders implements AdminOrdersPort {
  SupabaseAdminOrders({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Lists orders for the admin queue.
  ///
  /// RLS NOTE: the embedded `profiles(full_name)` is filtered by the
  /// caller's own profile policy, and `profiles` currently grants only
  /// `auth.uid() = id` — so an admin sees the orders but a NULL profile for
  /// other users, i.e. blank customer names. Until
  /// `supabase/migrations/_proposals/061_admin_profiles_read.sql` is applied,
  /// prefer [getOrderDetails] (RPC, RLS-bypassing, admin-checked) when the
  /// customer identity is required. The mapper degrades the missing profile
  /// to an empty name rather than throwing, which is why this shows up as a
  /// blank label instead of an error.
  /// The list query selects only the columns the queue cards render —
  /// never `*`. In particular `address_snapshot` (a heavy JSONB blob) is
  /// excluded: the queue never shows an address, and the detail view
  /// refetches via [getOrderDetails] (audit: perf — `select('*')` pulled
  /// the snapshot ×50 per load). [AdminMappers.orderFromRow] tolerates
  /// the absent key and yields `address: null` for queue rows.
  static const _orderListSelect =
      'id,status,total,placed_at,payment_method,payment_id,'
      'profiles(full_name),order_items(id)';

  @override
  Future<Result<List<AdminOrder>>> getAllOrders({
    AdminOrderStatus? status,
    int limit = 50,
  }) =>
      Result.guard(() async {
        final query = _client.from('orders').select(_orderListSelect);
        final filtered =
            status != null ? query.eq('status', status.dbValue) : query;
        final rows =
            await filtered.order('placed_at', ascending: false).limit(limit);
        return (rows as List)
            .whereType<Map<String, dynamic>>()
            // Rows without a string id cannot be navigated to; skip them.
            .where((r) => r['id'] is String)
            .map(AdminMappers.orderFromRow)
            .toList();
      }, 'Failed to load orders', code: kAdminOrdersLoadFailed);

  @override
  Future<Result<AdminOrder?>> getOrderDetails(String orderId) =>
      Result.guard(() async {
        // `get_order_details` (migration 017) is SECURITY DEFINER and verifies
        // owner/admin inside the function, so it can return the customer
        // profile. The previous embedded select
        // (`profiles(id, full_name, membership_tier)`) is subject to the
        // VIEWER's row-level security, and `profiles` only grants
        // `auth.uid() = id` (migration 002) — so the join came back null for
        // every other user's order and the admin lost the customer identity.
        final payload = await _client.rpc(
          'get_order_details',
          params: {'p_order_id': orderId},
        );
        final row = _orderRowFromRpc(payload);
        if (row == null) return null;
        return AdminMappers.orderDetailFromRow(row);
      }, 'Failed to load order', code: kAdminOrderLoadFailed);

  /// Reshapes the `get_order_details` payload
  /// (`{order: {...}, items: [...], customer: {...}}`) into the single row
  /// shape [AdminMappers.orderDetailFromRow] already understands
  /// (`orders` + `order_items` + `profiles`). Returns null when the RPC
  /// reports no order.
  static Map<String, dynamic>? _orderRowFromRpc(Object? payload) {
    final body = safeMap(payload);
    final order = body['order'];
    if (order is! Map) return null;
    // Copied, not mutated in place: the decoded payload must not be
    // altered under other readers.
    final row = Map<String, dynamic>.from(safeMap(order));
    final items = body['items'];
    row['order_items'] = items is List ? items : const <Object>[];
    final customer = body['customer'];
    // `customer` is only absent when the order has no profile row; the
    // mapper already degrades to a blank name in that case.
    if (customer is Map) row['profiles'] = safeMap(customer);
    return row;
  }

  @override
  Future<Result<void>> updateOrderStatus(
    String orderId,
    AdminOrderStatus status, {
    String? trackingNumber,
  }) async {
    // Pre-flight validation stays OUTSIDE the guard: it is a domain check with
    // its own message, not something the boundary should swallow and relabel.
    if (status == AdminOrderStatus.unknown) {
      return const Failure(
          AppError('Unknown order status', code: kAdminOrderStatusInvalid));
    }
    return Result.guard<void>(() async {
      await _client.rpc('update_order_status', params: {
        'p_order_id': orderId,
        'p_new_status': status.dbValue,
        'p_tracking_number': trackingNumber,
      });
    }, 'Failed to update order status', code: kAdminOrderStatusUpdateFailed);
  }
}
