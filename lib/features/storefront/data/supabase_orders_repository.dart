import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/address_codec.dart';
import '../../../core/entities/money.dart';
import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/safe_parse.dart';
import '../../../shared/services/logger.dart';
import '../domain/repositories/orders_repository.dart';

/// Supabase-backed orders repository.
///
/// Fetches orders from the `orders` + `order_items` tables. RLS policies
/// (migration 017) restrict rows to the current user or admin, so this
/// repository needs no additional authorization logic.
///
/// Registered in [service_locator.dart] for non-debug builds. When debug,
/// [LocalOrdersRepository] is used instead.
final class SupabaseOrdersRepository implements OrdersRepository {
  SupabaseOrdersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Upper bound on rows pulled per history fetch (audit P4). The admin
  /// queue already caps at 50; the storefront now matches instead of
  /// pulling unbounded history.
  static const int historyLimit = 50;

  @override
  Future<Result<List<Order>>> readOrders() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return Failure(AppError('Not authenticated'));
      }

      // Fetch orders with embedded items via a join. Supabase PostgREST
      // returns order_items as an array inside each order row.
      final rows = await _client
          .from('orders')
          .select('''
            id, status, subtotal, shipping, total,
            payment_method, address_snapshot, placed_at,
            order_items(
              product_id, product_name, size, color,
              unit_price, quantity
            )
          ''')
          .eq('user_id', userId)
          .order('placed_at', ascending: false)
          .limit(historyLimit);

      if (kDebugMode) {
        Log.w('readOrders: got ${rows.length} rows');
      }
      // Total decode (audit P2): rows without a usable id are skipped so
      // one malformed row can never fail the whole history load.
      final orders = rows.map(_mapOrder).whereType<Order>().toList();
      return Success(orders);
    } on Exception catch (e) {
      Log.e('readOrders failed', error: e);
      return Failure(AppError('Failed to load orders', cause: e));
    }
  }

  /// Total decode of an order row: every field degrades to the entity
  /// default instead of throwing; rows without a usable `id` return null
  /// so callers skip them (audit P2).
  static Order? _mapOrder(Map<String, dynamic> row) {
    final id = safeString(row, 'id');
    if (id.isEmpty) return null;

    final itemsRaw = row['order_items'];
    final items = itemsRaw is List
        ? itemsRaw.whereType<Map<String, dynamic>>().map(_mapOrderItem).toList()
        : <CartItem>[];

    final addressRaw = row['address_snapshot'];
    final address = addressRaw is Map
        ? AddressCodec.fromOrderJson(safeMap(addressRaw))
        : null;

    return Order(
      id: id,
      items: items,
      subtotal: Money(safeInt(row, 'subtotal')),
      shipping: Money(safeInt(row, 'shipping')),
      total: Money(safeInt(row, 'total')),
      status: _parseStatus(safeString(row, 'status')),
      placedAt:
          safeDateTime(row, 'placed_at') ?? DateTime.now(),
      paymentMethod: safeString(row, 'payment_method'),
      address: address,
    );
  }

  static CartItem _mapOrderItem(Map<String, dynamic> row) {
    return CartItem(
      product: Product(
        id: safeString(row, 'product_id'),
        name: safeString(row, 'product_name'),
        category: '',
        price: Money(safeInt(row, 'unit_price')),
        imageColor: 0xFF888888,
        sizes: const [],
        colors: const [],
        stock: const {},
      ),
      color: safeString(row, 'color'),
      length: safeString(row, 'size'),
      quantity: safeInt(row, 'quantity'),
    );
  }

  static OrderStatus _parseStatus(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => OrderStatus.placed,
    );
  }
}
