import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/pending_order.dart';
import '../domain/repositories/checkout_repository.dart';

/// Server-side checkout service.
///
/// Implements [CheckoutRepository] against the Supabase `checkout`
/// Edge Function. The cubit depends on the domain interface; this
/// is the concrete backing.
class CheckoutService implements CheckoutRepository {
  CheckoutService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Create a pending order via the `checkout` Edge Function.
  ///
  /// The server validates prices, decrements stock, and inserts a row with
  /// status='pending'. The returned [PendingOrder.orderId] is passed to
  /// `paymob-initiate`; the [PendingOrder.total] is the server-computed
  /// amount (in minor units) — never override it client-side.
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
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
          if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        },
      );

      if (response.status != 200) {
        final error = response.data;
        return Failure(AppError(error['message'] ?? 'Checkout failed'));
      }

      final data = response.data;
      return Success(PendingOrder(
        orderId: data['order_id'] as String,
        total: Money(data['total_cents'] as int),
        expiresAt: DateTime.parse(data['expires_at'] as String),
      ));
    } catch (e) {
      return Failure(AppError('Checkout failed: $e'));
    }
  }
}
