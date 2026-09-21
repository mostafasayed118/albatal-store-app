import '../../../../core/error/result.dart';
import '../entities/admin_coupon.dart';

/// Narrow port for admin coupon management (ISP).
///
/// Split out of [AdminRepository] (audit). [AdminCouponsCubit] depends on
/// this instead of the ~20-method facade.
abstract interface class AdminCouponsPort {
  /// All coupons, newest first (review-gated `coupons` table, 049).
  Future<Result<List<AdminCoupon>>> fetchCoupons();

  /// Creates or updates a coupon by code (server uppercases codes).
  Future<Result<AdminCoupon>> createCoupon({
    required String code,
    required int discountMinor,
    String? description,
  });

  /// Enables/disables a coupon without deleting it.
  Future<Result<void>> setCouponActive(String id, bool active);
}
