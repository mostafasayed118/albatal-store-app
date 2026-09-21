import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/coupon_discount.dart';

export '../domain/entities/coupon_discount.dart'
    show kCouponInvalid, kCouponUnavailable;

/// Maps a `validate_coupon` RPC row to [CouponDiscount].
///
/// Fail closed: a row without a usable code or discount yields null so
/// the caller rejects the coupon instead of inventing a discount.
///
/// Outcome codes ([kCouponInvalid], [kCouponUnavailable]) are defined in
/// the domain layer and re-exported here so existing importers keep
/// working.
CouponDiscount? couponFromRow(Map<String, dynamic> row) {
  final code = safeString(row, 'code').toUpperCase();
  final discount = safeInt(row, 'discount_minor');
  if (code.isEmpty || discount <= 0) {
    return null;
  }
  return CouponDiscount(
    code: code,
    discountMinor: discount,
    description: safeString(row, 'description'),
  );
}
