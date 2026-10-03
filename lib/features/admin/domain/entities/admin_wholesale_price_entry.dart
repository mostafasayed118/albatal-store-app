import 'package:equatable/equatable.dart';

/// Admin-facing wholesale price-list row (078 B2B).
///
/// One negotiated unit price per product for wholesale members; the
/// `tier` column is reserved for future sub-tiers and currently pins
/// to 'wholesale', so it is not surfaced here.
final class AdminWholesalePriceEntry extends Equatable {
  const AdminWholesalePriceEntry({
    required this.productId,
    required this.productName,
    required this.priceMinor,
    this.updatedAt,
  });

  final String productId;
  final String productName;
  final int priceMinor;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [productId, productName, priceMinor, updatedAt];
}
