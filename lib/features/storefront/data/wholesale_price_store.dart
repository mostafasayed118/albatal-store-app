import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/money.dart';
import '../../../shared/services/logger.dart';
import '../domain/repositories/wholesale_price_source.dart';

/// Supabase-backed [WholesalePriceSource] over `wholesale_price_lists`
/// (migration 078). Read-only by design — writes go through the admin
/// RPCs (`admin_upsert_wholesale_price` / `admin_delete_wholesale_price`).
///
/// Fail-soft contract: ANY error (RLS denial, pre-078 backend, offline)
/// degrades to an empty map — the caller renders catalog prices and the
/// server stays authoritative at checkout. Rows for future sub-tiers are
/// filtered out explicitly so a widened `tier` CHECK cannot silently
/// change what this store returns.
final class SupabaseWholesalePriceSource implements WholesalePriceSource {
  SupabaseWholesalePriceSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, Money>> fetchWholesalePrices(
      Iterable<String> productIds) async {
    final ids = productIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('wholesale_price_lists')
          .select('product_id, price_minor')
          .eq('tier', 'wholesale')
          .inFilter('product_id', ids.toList());
      final prices = <String, Money>{};
      for (final row in rows) {
        final productId = row['product_id'];
        final priceMinor = row['price_minor'];
        if (productId is! String || productId.isEmpty) continue;
        if (priceMinor is! num || priceMinor <= 0) continue;
        prices[productId] = Money(priceMinor.toInt());
      }
      return prices;
    } catch (e) {
      // Expected for non-wholesale sessions (RLS 0-row is NOT an error,
      // but a pre-078 backend or an offline probe 403s) — degrade, never
      // break the page.
      Log.w('Wholesale price-list fetch failed.', error: e);
      return const {};
    }
  }
}
