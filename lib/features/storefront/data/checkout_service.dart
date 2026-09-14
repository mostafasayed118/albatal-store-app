import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../../../../shared/services/logger.dart';
import '../../payments/domain/entities/payment.dart';
import '../domain/entities/pending_order.dart';
import '../domain/pricing/cut_length_pricing.dart';
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
    String? couponCode,
    String? idempotencyKey,
  }) async {
    final response = await Result.guard(
      () => _client.rpc(
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
                    // Wave C: sample lines are flagged so the checkout
                    // flow can apply the fixed sample price server-side
                    // (enforcement = pending supabase/ follow-up; extra
                    // JSON keys are ignored by the pre-update RPC).
                    if (item.sample) 'sample': true,
                    // Metered lines carry the cut meters plus the client
                    // estimate so the server can cross-check; when the
                    // wholesale tier dropped the per-meter price, the
                    // discounted value rides along as `tiered_price`
                    // (minor units) for server-side validation.
                    if (item.cutMeters case final meters?) ...{
                      'meters': meters,
                      'line_total': item.effectiveLineTotal.minorUnits,
                      if (item.effectivePerMeterPrice! != item.product.price)
                        'tiered_price': item.effectivePerMeterPrice!.minorUnits,
                    },
                  })
              .toList(),
          // §8: only sent when a coupon validated — the pre-049 RPC
          // would reject an unknown parameter, so absence == compatibility.
          if (couponCode != null) 'p_coupon_code': couponCode,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      ),
      'Checkout failed',
      onError: _checkoutError,
    );

    return response.when(
      success: (data) {
        // Total decode (audit P2): the RPC is server-authoritative, but a
        // malformed payload must degrade to a user-safe Failure instead of
        // throwing a TypeError into the catch-all below. Fail closed on a
        // missing order id or expiry — a half-decoded order would corrupt
        // the payment hand-off.
        final map = safeMap(data);
        final orderId = safeString(map, 'order_id');
        final expiresAt = safeDateTime(map, 'expires_at');
        final subtotal = _minorUnits(map['subtotal']);
        final shipping = _minorUnits(map['shipping']);
        final total = _minorUnits(map['total']);
        if (orderId.isEmpty ||
            expiresAt == null ||
            subtotal == null ||
            shipping == null ||
            total == null) {
          Log.e('Checkout RPC malformed payload', category: LogCategory.error);
          return const Failure<PendingOrder>(
              AppError('Checkout failed', code: kCheckoutFailedCode));
        }
        return Success<PendingOrder>(PendingOrder(
          orderId: orderId,
          subtotal: Money(subtotal),
          shipping: Money(shipping),
          total: Money(total),
          expiresAt: expiresAt,
          status: safeString(map, 'status', fallback: 'pending'),
          isIdempotentRetry: safeBool(map, 'idempotent'),
        ));
      },
      failure: (error) => Failure<PendingOrder>(error),
    );
  }

  /// Allowlist-map of Postgrest failures to user-safe messages.
  ///
  /// The RPC raises server-side; only explicitly recognized signals get
  /// specific copy — unknown codes/messages collapse to generic
  /// 'Checkout failed' so SQL/URL internals never reach the UI.
  String _userMessageForPostgrest(PostgrestException e) {
    final code = (e.code ?? '').toUpperCase();
    final msg = e.message.toLowerCase();
    // Known safe signals (keep tiny; expand only with server contract).
    if (code == '23505' ||
        msg.contains('duplicate') ||
        msg.contains('already')) {
      return 'Checkout failed';
    }
    if (msg.contains('insufficient stock') || msg.contains('out of stock')) {
      return 'Some items are out of stock.';
    }
    if (msg.contains('invalid payment method') ||
        msg.contains('unsupported payment')) {
      return 'Unsupported payment method.';
    }
    return 'Checkout failed';
  }

  /// [Result.guard] error-mapper for the checkout RPC.
  ///
  /// Never surfaces Postgrest text verbatim (can leak SQL/URLs).
  /// Allowlist-maps known safe signals; everything else collapses to
  /// the generic message (Paymob-service pattern). Detail stays in
  /// logs with cause/stack.
  AppError _checkoutError(Object e, StackTrace st) {
    if (e is PostgrestException) {
      Log.e('Checkout RPC failed', error: e, stackTrace: st);
      final message = _userMessageForPostgrest(e);
      return AppError(message,
          cause: e,
          stackTrace: st,
          code: message == 'Checkout failed' ? kCheckoutFailedCode : null);
    }
    // Never interpolate the raw exception: transport failures can carry
    // internal URLs and secrets that must not reach the UI (audit P1).
    Log.e('Checkout failed', error: e, stackTrace: st);
    return AppError('Checkout failed',
        cause: e, stackTrace: st, code: kCheckoutFailedCode);
  }
}
