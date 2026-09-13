import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/coupon_discount.dart';

/// Maps a `validate_coupon` RPC row to [CouponDiscount].
///
/// Fail closed: a row without a usable code or discount yields null so
/// the caller rejects the coupon instead of inventing a discount.
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

/// Stable UI-facing machine codes for coupon outcomes.
const kCouponInvalid = 'coupon_invalid';
const kCouponUnavailable = 'coupon_unavailable';
