import 'package:equatable/equatable.dart';

/// Stable UI-facing machine codes for coupon outcomes.
///
/// Lives in the domain layer (not `data/coupon_mapper.dart`) so both the
/// data layer (which authors them) and the presentation layer (which
/// matches on them) can share one definition without the presentation
/// layer importing from data (audit: magic-string duplication +
/// layering).
const kCouponInvalid = 'coupon_invalid';
const kCouponUnavailable = 'coupon_unavailable';

/// Server-validated coupon (feature-batch §8). The discount amount is
/// computed server-side by `validate_coupon` / `create_checkout_order`
/// — the client only carries and displays it.
final class CouponDiscount extends Equatable {
  const CouponDiscount({
    required this.code,
    required this.discountMinor,
    this.description,
  });

  /// Normalized (uppercased, trimmed) code as returned by the server.
  final String code;

  /// Discount in minor units (cents), server-computed.
  final int discountMinor;

  final String? description;

  @override
  List<Object?> get props => [code, discountMinor, description];
}
