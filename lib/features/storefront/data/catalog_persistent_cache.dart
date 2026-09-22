import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/product.dart';
import '../../../shared/services/logger.dart';
import 'product_mapper.dart';

/// SharedPreferences persistent cache for the catalog repository.
///
/// Extracted from `SupabaseCatalogRepository` so that file stays under the
/// size budget. Same fail-soft contract: cache writes/restores never throw
/// into the repository — corruption degrades to a skip (logged without the
/// raw payload text; audit 2026-09-14 P0-5).

/// SharedPreferences key for the persistent catalog cache.
const catalogPersistentCacheKey = 'catalog_products_cache_v1';

/// Payloads at or below this size parse inline: spawning an isolate
/// costs more (milliseconds + cold-start latency on the offline
/// fallback path) than parsing tens of KB itself. Only larger
/// payloads go through [compute] (audit P6).
const _isolateJsonChars = 64 * 1024;

/// Item-count twin of [_isolateJsonChars] for the encode direction,
/// where the string length is unknown before encoding. A full
/// 100-row catalog page serializes to tens of KB, so above this
/// count the encode moves off the UI thread.
const _isolateItemBudget = 40;

/// Writes [products] to the persistent cache. Best-effort — never throws.
Future<void> persistCatalogCache(
  SharedPreferences? prefs,
  List<Product> products,
) async {
  if (prefs == null) return;
  try {
    final encoded = products.map(ProductCodec.encode).toList();
    // Large catalogs encode off the UI thread (audit P6); small ones
    // inline — see [_isolateItemBudget]. `jsonEncode` is a top-level
    // function, so it can go straight into `compute` (maps of
    // primitives cross the isolate).
    final json = products.length > _isolateItemBudget
        ? await compute(jsonEncode, encoded)
        : jsonEncode(encoded);
    await prefs.setString(catalogPersistentCacheKey, json);
  } catch (e) {
    // Best-effort cache write — never crash the app over persistence.
    // Logged without the raw error text; audit 2026-09-14 P0-5.
    Log.w('Catalog persistent cache write failed.', error: e);
  }
}

/// Reads the persistent cache, or null when absent/unusable. Never throws.
Future<List<Product>?> restoreCatalogCache(SharedPreferences? prefs) async {
  if (prefs == null) return null;
  try {
    final raw = prefs.getString(catalogPersistentCacheKey);
    if (raw == null) return null;
    // Decode off the UI thread for large payloads only (audit P6,
    // gated by [_isolateJsonChars]): this restore sits on the offline
    // cold-start path, where isolate spawn latency would delay first
    // paint for the common small-cache case.
    final decoded = raw.length > _isolateJsonChars
        ? await compute(jsonDecode, raw)
        : jsonDecode(raw);
    if (decoded is! List) return null;
    // Per-item fail-soft: a corrupt/tampered entry is skipped, never
    // fatal to its neighbours (previously one throwing entry discarded
    // the whole cache via the catch-all below).
    final products = <Product>[];
    for (final entry in decoded) {
      try {
        if (entry is! Map) continue;
        final product = ProductCodec.decode(entry as Map<Object?, Object?>);
        if (product != null) products.add(product);
      } catch (e) {
        // Per-entry fail-soft (logged without payload text; P0-5).
        Log.w('Catalog persistent cache skipping corrupt entry.', error: e);
      }
    }
    return products;
  } catch (e) {
    // Fail-soft restore (logged without payload text; P0-5).
    Log.w('Catalog persistent cache restore failed.', error: e);
    return null;
  }
}
