import 'package:equatable/equatable.dart';

/// Admin-facing coupon row (feature-batch §8).
final class AdminCoupon extends Equatable {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.discountMinor,
    required this.active,
    this.description,
  });

  final String id;
  final String code;
  final int discountMinor;
  final bool active;
  final String? description;

  AdminCoupon copyWith({bool? active}) => AdminCoupon(
        id: id,
        code: code,
        discountMinor: discountMinor,
        active: active ?? this.active,
        description: description,
      );

  @override
  List<Object?> get props => [id, code, discountMinor, active, description];
}
