import '../../../../core/error/result.dart';
import '../entities/coupon_discount.dart';
import '../repositories/coupons_repository.dart';

/// Server coupon validation as a domain use-case (audit Top-5 #5).
///
/// [CheckoutCubit.applyCoupon] delegated directly to [CouponsRepository];
/// routing through this use-case keeps the cubit thin (order placement +
/// state only) and gives widget tests a single seam to fake. No policy
/// lives here — validation failures (invalid code, backend not deployed)
/// propagate as [Result] and the cubit maps them to `couponMessage`.
final class ValidateCouponUseCase {
  ValidateCouponUseCase({required CouponsRepository coupons})
      : _coupons = coupons;

  final CouponsRepository _coupons;

  Future<Result<CouponDiscount>> call(String code) => _coupons.validate(code);
}
