import 'dart:async';

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
  CheckoutService(
      {SupabaseClient? client, Duration rpcTimeout = _defaultRpcTimeout})
      : _client = client ?? Supabase.instance.client,
        _rpcTimeout = rpcTimeout;

  final SupabaseClient _client;
  final Duration _rpcTimeout;

  /// Bound for the `create_checkout_order` RPC: a hung request must not
  /// stall checkout forever (hotel-wifi / captive portals / dead
  /// sockets). A timeout never fabricates an order — it surfaces a
  /// recoverable failure and the caller retries with the same
  /// idempotency key, so the server dedupes instead of double-charging
  /// stock. Overridable for deterministic timeout tests.
  static const _defaultRpcTimeout = Duration(seconds: 15);

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
      ).timeout(_rpcTimeout);

      // The RPC returns a single JSON object; anything else (list, null,
      // scalar) is a contract violation. [safeMap] normalizes maps and
      // degrades anything else to empty, so the strict checks below fail
      // closed instead of throwing a TypeError into the cubit.
      final data = safeMap(response);

      // Identity + expiry are load-bearing: never default them to a
      // placeholder that could flow into payment.
      final orderId = data['order_id'];
      if (orderId is! String || orderId.isEmpty) {
        return const Failure(AppError('Checkout failed'));
      }
      final expiresRaw = data['expires_at'];
      final expiresAt =
          expiresRaw is String ? DateTime.tryParse(expiresRaw) : null;
      if (expiresAt == null) {
        return const Failure(AppError('Checkout failed'));
      }

      // Money is fail-closed too: a missing total must never degrade to
      // `Money(0)` and proceed to payment. `num` (not `int`) accepts
      // integer-valued doubles the serializer may produce.
      final subtotal = data['subtotal'];
      final shipping = data['shipping'];
      final total = data['total'];
      if (subtotal is! num || shipping is! num || total is! num) {
        return const Failure(AppError('Checkout failed'));
      }

      return Success(PendingOrder(
        orderId: orderId,
        subtotal: Money(subtotal.toInt()),
        shipping: Money(shipping.toInt()),
        total: Money(total.toInt()),
        expiresAt: expiresAt,
        status: safeString(data, 'status', fallback: 'pending'),
        isIdempotentRetry: safeBool(data, 'idempotent'),
      ));
    } on TimeoutException {
      // Hung RPC: safe to retry with the same idempotency key — the
      // server either never saw the request or never answered it.
      // Never interpolate: the timeout has no safe detail to show.
      return const Failure(AppError('Checkout failed'));
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
