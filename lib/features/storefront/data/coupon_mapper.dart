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

/// Maps the raw `validate_coupon` RPC payload to [CouponDiscount].
///
/// Total by design (audit 2026-09-21): the payload arrives as `dynamic` from
/// PostgREST, so a scalar, a list of non-maps, or any other hostile shape
/// degrades to null ("invalid coupon") instead of throwing a [TypeError]
/// past the caller's error boundary.
CouponDiscount? couponFromRpcPayload(Object? rows) {
  final list = rows is List ? rows : const <Object?>[];
  if (list.isEmpty) {
    return null;
  }
  return couponFromRow(safeMap(list.first));
}
