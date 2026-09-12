import '../../../../core/error/result.dart';
import '../entities/coupon_discount.dart';

/// Coupon validation port (feature-batch §8).
abstract interface class CouponsRepository {
  /// Validates [code] against the server (`validate_coupon` RPC).
  ///
  /// Returns a Failure with a stable machine-readable prefix when the
  /// coupon backend is not deployed yet (`coupon_unavailable`) or the
  /// code is rejected (`coupon_invalid`) — the checkout can proceed
  /// without a coupon in both cases.
  Future<Result<CouponDiscount>> validate(String code);
}
