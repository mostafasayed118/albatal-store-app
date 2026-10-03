import '../../../../core/entities/money.dart';

/// Wholesale price-list reader (migration 078, B2B follow-up).
///
/// The `wholesale_price_lists` table is RLS-gated server-side: only
/// wholesale members (+ admins) see rows. This port therefore carries no
/// tier argument — callers gate on the viewer's tier to skip the query
/// for everyone else, and the server fails closed for anyone who asks
/// anyway. Implementations MUST fail soft (empty map, never throw) so a
/// pre-078 backend or an RLS denial degrades to "no list price" instead
/// of breaking the product page.
abstract interface class WholesalePriceSource {
  /// Negotiated wholesale unit price (minor units) per product id, for
  /// the products in [productIds] that carry a list row. Missing ids are
  /// simply absent from the map — absence means "resolve as usual".
  Future<Map<String, Money>> fetchWholesalePrices(Iterable<String> productIds);
}
