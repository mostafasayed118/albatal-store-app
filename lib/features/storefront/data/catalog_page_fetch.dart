import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/product.dart';
import '../../../shared/services/logger.dart';
import '../../../shared/services/storage_service.dart';
import 'product_mapper.dart';

/// Single bounded catalog page fetch for [SupabaseCatalogRepository].
///
/// Runs the products query with embedded variant + image relations
/// (one round-trip), maps rows via [ProductCodec.listFromRows], and
/// reports whether the page came back full. The caller owns caching,
/// persistence, and the offline fallback — this function only fetches.
///
/// Throws on transport failure; the caller degrades to its caches.
///
/// Truncation signal: the fetch is bounded, and every search/filter/sort
/// pass runs CLIENT-side over the page, so a full page means the catalog
/// has outgrown the bound and results are silently incomplete. Logged
/// (not thrown) so the storefront keeps working while the owner decides
/// between a larger page and server-side search.
Future<({List<Product> products, bool truncated})> fetchCatalogPage({
  required SupabaseClient client,
  required StorageService storageService,
  required String productSelect,
  required int limit,
}) async {
  // `.order('name')` is kept so the bounded page is deterministic.
  final rows = await client
      .from('products')
      .select(productSelect)
      .eq('is_active', true)
      .order('name')
      .limit(limit);

  final products = ProductCodec.listFromRows(
    rows,
    storageService: storageService,
  );

  final truncated = products.length >= limit;
  if (truncated) {
    Log.w(
      'Catalog page is full ($limit rows): client-side search/filter '
      'cannot see products beyond this page.',
    );
  }
  return (products: products, truncated: truncated);
}
