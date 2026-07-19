import '../../../../core/entities/product.dart';
import '../../../../core/error/result.dart';
import '../entities/pending_order.dart';

/// Domain port for the checkout flow.
///
/// The data layer ([CheckoutService]) implements this against the
/// Supabase `checkout` Edge Function. The presentation layer
/// ([CheckoutCubit]) depends only on this interface.
abstract interface class CheckoutRepository {
  Future<Result<PendingOrder>> placeOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required Map<String, dynamic> addressSnapshot,
    String? idempotencyKey,
  });
}
