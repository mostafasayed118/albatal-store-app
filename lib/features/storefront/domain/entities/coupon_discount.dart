import 'package:equatable/equatable.dart';

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
