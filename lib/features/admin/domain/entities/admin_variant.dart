import '../../../../core/entities/money.dart';

/// A product variant as returned by the admin `product_variants` query.
///
/// Typed replacement for the raw `Map<String, dynamic>` rows the variant
/// editor previously consumed; the mapper owns every cast so malformed
/// rows degrade to safe defaults instead of throwing in the UI.
final class AdminVariant {
  const AdminVariant({
    required this.variantId,
    required this.size,
    required this.color,
    required this.stock,
    this.priceOverride,
  });

  /// `product_variants.id` — used by the variant upsert flow.
  final String variantId;
  final String size;
  final String color;
  final int stock;

  /// `price_override` in integer minor units; null means "inherits base price".
  final Money? priceOverride;
}
