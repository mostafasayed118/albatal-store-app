import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/address.dart';
import '../../../core/entities/money.dart';
import '../../../core/entities/order.dart';
import '../../../core/entities/product.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/orders_repository.dart';

/// Supabase-backed orders repository.
///
/// Fetches orders from the `orders` + `order_items` tables. RLS policies
/// (migration 017) restrict rows to the current user or admin, so this
/// repository needs no additional authorization logic.
///
/// Registered behind a feature flag in [service_locator.dart]. When the
/// flag is off, [LocalOrdersRepository] is used instead.
final class SupabaseOrdersRepository implements OrdersRepository {
  SupabaseOrdersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<List<Order>>> readOrders() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return Failure(AppError('Not authenticated'));
      }

      // Fetch orders with embedded items via a join. Supabase PostgREST
      // returns order_items as an array inside each order row.
      final rows = await _client.from('orders').select('''
            id, status, subtotal, shipping, total,
            payment_method, address_snapshot, placed_at,
            order_items(
              product_id, product_name, size, color,
              unit_price, quantity
            )
          ''').eq('user_id', userId).order('placed_at', ascending: false);

      final orders = rows.map(_mapOrder).toList();
      return Success(orders);
    } on Exception catch (e) {
      return Failure(AppError('Failed to load orders', cause: e));
    }
  }

  @override
  Future<Result<void>> writeOrders(List<Order> orders) async {
    // Server-backed repository is read-only from the client side.
    // Orders are created via the `create_checkout_order` RPC and
    // updated via Edge Function webhooks. writeOrders is a no-op
    // here to satisfy the interface contract.
    return const Success(null);
  }

  // ─── Mapping helpers ────────────────────────────────────────

  static Order _mapOrder(Map<String, dynamic> row) {
    final itemsRaw = row['order_items'];
    final items = itemsRaw is List
        ? itemsRaw.whereType<Map<String, dynamic>>().map(_mapOrderItem).toList()
        : <CartItem>[];

    final addressRaw = row['address_snapshot'] as Map<String, dynamic>?;
    final address = addressRaw != null ? _mapAddress(addressRaw) : null;

    return Order(
      id: row['id'] as String,
      items: items,
      subtotal: Money(row['subtotal'] as int),
      shipping: Money(row['shipping'] as int),
      total: Money(row['total'] as int),
      status: _parseStatus(row['status'] as String),
      placedAt: DateTime.parse(row['placed_at'] as String),
      paymentMethod: row['payment_method'] as String,
      address: address,
    );
  }

  static CartItem _mapOrderItem(Map<String, dynamic> row) {
    return CartItem(
      product: Product(
        id: row['product_id'] as String,
        name: row['product_name'] as String,
        category: '',
        price: Money(row['unit_price'] as int),
        imageColor: 0xFF888888,
        sizes: const [],
        colors: const [],
        stock: const {},
      ),
      color: row['color'] as String,
      length: row['size'] as String,
      quantity: row['quantity'] as int,
    );
  }

  static Address _mapAddress(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String? ?? '',
      recipient: json['recipient'] as String? ?? '',
      line: json['line'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }

  static OrderStatus _parseStatus(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => OrderStatus.placed,
    );
  }
}
