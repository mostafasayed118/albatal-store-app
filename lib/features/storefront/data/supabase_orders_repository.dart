import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/orders_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/order.dart';

/// Supabase-backed orders repository.
///
/// Orders are read-only from the client side. Creation happens
/// through a server-side function (Phase 8) for security.
class SupabaseOrdersRepository implements OrdersRepository {
  SupabaseOrdersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _user => _client.auth.currentUser!;

  @override
  Future<List<Order>> readOrders() async {
    final response = await _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', _user.id)
        .order('placed_at', ascending: false);

    return (response as List).map((row) {
      final items = (row['order_items'] as List).map((item) {
        return CartItem(
          product: Product(
            id: item['product_id'] as String,
            name: item['product_name'] as String,
            category: '',
            price: Money(item['unit_price'] as int),
            imageColor: 0xFF176B57,
          ),
          color: item['color'] as String,
          length: item['size'] as String,
          quantity: item['quantity'] as int,
        );
      }).toList();

      return Order(
        id: row['id'] as String,
        items: items,
        subtotal: Money(row['subtotal'] as int),
        shipping: Money(row['shipping'] as int),
        total: Money(row['total'] as int),
        status: OrderStatus.values.firstWhere(
          (s) => s.name == row['status'],
          orElse: () => OrderStatus.placed,
        ),
        placedAt: DateTime.parse(row['placed_at'] as String),
        paymentMethod: row['payment_method'] as String,
      );
    }).toList();
  }

  @override
  Future<void> writeOrders(List<Order> orders) async {
    // Client-side orders are read-only in the Supabase model.
    // Order creation happens via server-side functions.
    // This method is a no-op for the remote implementation.
  }
}
