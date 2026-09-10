import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../payments/domain/entities/payment.dart';
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

  /// Minor-unit extractor for server-computed money fields.
///
/// JSON numbers arrive as `int` or `double`; both are accepted and
/// truncated to integer minor units. Anything else (null, string, bool)
/// yields null so the caller can fail closed.
int? _minorUnits(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

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
    required PaymentMethod paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc(
        'create_checkout_order',
        params: {
          // Single source of truth: the enum's serverValue matches the
          // strings the server gates on ('paymob_card' for 035/initiate,
          // 'cod' for COD confirm). Never send display strings.
          'p_payment_method': paymentMethod.serverValue,
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

      // Total decode (audit P2): the RPC is server-authoritative, but a
      // malformed payload must degrade to a user-safe Failure instead of
      // throwing a TypeError into the catch-all below. Fail closed on a
      // missing order id or expiry — a half-decoded order would corrupt
      // the payment hand-off.
      final data = safeMap(response);
      final orderId = safeString(data, 'order_id');
      final expiresAt = safeDateTime(data, 'expires_at');
      final subtotal = _minorUnits(data['subtotal']);
      final shipping = _minorUnits(data['shipping']);
      final total = _minorUnits(data['total']);
      if (orderId.isEmpty ||
          expiresAt == null ||
          subtotal == null ||
          shipping == null ||
          total == null) {
        return const Failure(AppError('Checkout failed'));
      }
      return Success(PendingOrder(
        orderId: orderId,
        subtotal: Money(subtotal),
        shipping: Money(shipping),
        total: Money(total),
        expiresAt: expiresAt,
        status: safeString(data, 'status', fallback: 'pending'),
        isIdempotentRetry: safeBool(data, 'idempotent'),
      ));
    } on PostgrestException catch (e) {
      final message = e.message;
      return Failure(
          AppError(message.isNotEmpty ? message : 'Checkout failed'));
    } catch (_) {
      // Never interpolate the raw exception: transport failures can carry
      // internal URLs and secrets that must not reach the UI (audit P1).
      return const Failure(AppError('Checkout failed'));
    }
  }
}
