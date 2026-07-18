import 'package:supabase_flutter/supabase_flutter.dart';

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
      return Success(Order(
        id: data['order_id'] as String,
        items: items,
        subtotal: (data['subtotal'] as int) / 100,
        shipping: (data['shipping'] as int) / 100,
        total: (data['total'] as int) / 100,
        status: OrderStatus.placed,
        placedAt: DateTime.now(),
        paymentMethod: paymentMethod,
      ));
    } catch (e) {
      return Failure(AppError('Checkout failed: $e'));
    }
  }
}
