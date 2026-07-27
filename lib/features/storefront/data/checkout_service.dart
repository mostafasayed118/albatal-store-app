import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/pending_order.dart';
import '../domain/repositories/checkout_repository.dart';

/// Server-authoritative checkout service.
///
/// Implements [CheckoutRepository] by calling the
/// `create_checkout_order` PostgreSQL RPC (migration 013) directly
/// via the Supabase client. The RPC is `SECURITY DEFINER` so it
/// bypasses RLS, authenticates the user via `auth.uid()`, and runs
/// the entire order creation in a single atomic transaction.
///
/// The client never sends price, shipping, total, or user id — only
/// product/variant identifiers, quantities, the address snapshot,
/// and an idempotency key. All money is computed server-side.
class CheckoutService implements CheckoutRepository {
  CheckoutService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Create a pending order via the `create_checkout_order` RPC.
  ///
  /// The server validates prices, checks stock, calculates shipping
  /// from the configured shipping-zone logic, decrements stock, and
  /// inserts the order + items — all in one transaction. The returned
  /// [PendingOrder] carries the server-computed totals (the source
  /// of truth, never overridden client-side).
  @override
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc(
        'create_checkout_order',
        params: {
          'p_payment_method': paymentMethod,
          'p_address': addressSnapshot,
          'p_items': items
              .map((item) => {
                    'product_id': item.product.id,
                    'size': item.length,
                    'color': item.color,
                    'quantity': item.quantity,
                  })
              .toList(),
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );

      final data = response as Map<String, dynamic>;
      return Success(PendingOrder(
        orderId: data['order_id'] as String,
        subtotal: Money(data['subtotal'] as int),
        shipping: Money(data['shipping'] as int),
        total: Money(data['total'] as int),
        expiresAt: DateTime.parse(data['expires_at'] as String),
        status: data['status'] as String? ?? 'pending',
        isIdempotentRetry: data['idempotent'] as bool? ?? false,
      ));
    } on PostgrestException catch (e) {
      final message = e.message;
      return Failure(
          AppError(message.isNotEmpty ? message : 'Checkout failed'));
    } catch (e) {
      return Failure(AppError('Checkout failed: $e'));
    }
  }
}
