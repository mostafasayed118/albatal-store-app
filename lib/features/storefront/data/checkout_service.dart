import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/order.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';

/// Server-side checkout service.
class CheckoutService {
  CheckoutService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Result<Order>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'checkout',
        body: {
          'payment_method': paymentMethod,
          'address_snapshot': addressSnapshot,
          'items': items
              .map((item) => {
                    'product_id': item.product.id,
                    'size': item.length,
                    'color': item.color,
                    'quantity': item.quantity,
                  })
              .toList(),
        },
      );

      if (response.status != 200) {
        final error = response.data;
        return Failure(AppError(error['message'] ?? 'Checkout failed'));
      }

      final data = response.data;
      // Server returns money as integer minor units (cents);
      // Money carries the same representation — no conversion needed.
      return Success(Order(
        id: data['order_id'] as String,
        items: items,
        subtotal: Money(data['subtotal'] as int),
        shipping: Money(data['shipping'] as int),
        total: Money(data['total'] as int),
        status: OrderStatus.placed,
        placedAt: DateTime.now(),
        paymentMethod: paymentMethod,
      ));
    } catch (e) {
      return Failure(AppError('Checkout failed: $e'));
    }
  }
}
