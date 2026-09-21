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
  CheckoutService({required SupabaseClient client}) : _client = client;

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
        Log.e('Checkout RPC malformed payload', category: LogCategory.error);
        return const Failure(
            AppError('Checkout failed', code: kCheckoutFailedCode));
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
    } on PostgrestException catch (e, st) {
      // Never surface Postgrest text verbatim (can leak SQL/URLs).
      // Allowlist-map known safe signals; everything else collapses to
      // the generic message (Paymob-service pattern). Detail stays in
      // logs with cause/stack.
      Log.e('Checkout RPC failed', error: e, stackTrace: st);
      final outcome = _userMessageForPostgrest(e);
      return Failure(AppError(outcome.message,
          cause: e, stackTrace: st, code: outcome.code));
    } catch (e, st) {
      // Never interpolate the raw exception: transport failures can carry
      // internal URLs and secrets that must not reach the UI (audit P1).
      Log.e('Checkout failed', error: e, stackTrace: st);
      return Failure(AppError('Checkout failed',
          cause: e, stackTrace: st, code: kCheckoutFailedCode));
    }
  }

  /// Allowlist-map of Postgrest failures to user-safe messages.
  ///
  /// The RPC raises server-side; only explicitly recognized signals get
  /// specific copy — unknown codes/messages collapse to generic
  /// 'Checkout failed' so SQL/URL internals never reach the UI.
  ///
  /// Every outcome carries [kCheckoutFailedCode]: all three messages are
  /// app-authored English, so the page can localize via the code instead
  /// of matching the literal (audit: `message == 'Checkout failed'`
  /// silently reverted the screen to English on any copy edit).
  ({String message, String code}) _userMessageForPostgrest(
      PostgrestException e) {
    final code = (e.code ?? '').toUpperCase();
    final msg = e.message.toLowerCase();
    // Known safe signals (keep tiny; expand only with server contract).
    if (code == '23505' ||
        msg.contains('duplicate') ||
        msg.contains('already')) {
      return (message: 'Checkout failed', code: kCheckoutFailedCode);
    }
    if (msg.contains('insufficient stock') || msg.contains('out of stock')) {
      return (
        message: 'Some items are out of stock.',
        code: kCheckoutFailedCode
      );
    }
    if (msg.contains('invalid payment method') ||
        msg.contains('unsupported payment')) {
      return (
        message: 'Unsupported payment method.',
        code: kCheckoutFailedCode
      );
    }
    return (message: 'Checkout failed', code: kCheckoutFailedCode);
  }
}
