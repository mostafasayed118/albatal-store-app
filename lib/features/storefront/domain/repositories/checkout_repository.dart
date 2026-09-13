import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../../../payments/domain/entities/payment.dart';
import '../entities/pending_order.dart';

/// Domain port for the checkout flow.
///
/// The data layer ([CheckoutService]) implements this against the
/// Supabase `checkout` Edge Function. The presentation layer
/// ([CheckoutCubit]) depends only on this interface.
abstract interface class CheckoutRepository {
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? couponCode,
    String? idempotencyKey,
  });
}

/// Machine code carried by generic checkout failures, so the UI maps
/// them by code instead of string-matching English messages
/// (audit 2026-09-13). Domain-located so the data raiser and the
/// presentation mapper share one name without importing each other.
const kCheckoutFailedCode = 'checkout_failed';
