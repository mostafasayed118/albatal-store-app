/// A product variant at or below the low-stock threshold, as returned by
/// the `get_low_stock_products` RPC.
///
/// Typed replacement for the raw `Map<String, dynamic>` rows the admin
/// inventory screen previously consumed; the mapper owns every cast so
/// malformed rows degrade to safe defaults instead of throwing in the UI.
final class LowStockVariant {
  const LowStockVariant({
    required this.variantId,
    required this.productName,
    required this.size,
    required this.color,
    required this.stock,
  });

  /// `product_variants.id` — used by the stock-update flow.
  final String variantId;
  final String productName;
  final String size;
  final String color;
  final int stock;

  /// Compact "size / color" label for list subtitles.
  String get variantLabel => '$size / $color';
}
