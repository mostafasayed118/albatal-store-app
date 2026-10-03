import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/admin_wholesale_price_entry.dart';
import '../domain/repositories/admin_wholesale_prices_port.dart';

/// Wholesale price-list reads/writes for [SupabaseAdminRepository].
///
/// Implements [AdminWholesalePricesPort] against Supabase (078 B2B);
/// the facade keeps the `AdminRepository` surface and delegates here
/// unchanged.
final class SupabaseAdminWholesalePrices implements AdminWholesalePricesPort {
  SupabaseAdminWholesalePrices({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<List<AdminWholesalePriceEntry>>> fetchWholesalePrices() =>
      Result.guard(() async {
        final rows = await _client
            .from('wholesale_price_lists')
            .select('product_id, tier, price_minor, updated_at, products(name)')
            .eq('tier', 'wholesale');
        // `rows` is statically List via the typed Postgrest builder.
        final entries = rows
            .whereType<Map<String, dynamic>>()
            .map(_entryFromRow)
            .whereType<AdminWholesalePriceEntry>()
            .toList()
          ..sort((a, b) => a.productName
              .toLowerCase()
              .compareTo(b.productName.toLowerCase()));
        return entries;
      }, 'Failed to fetch wholesale prices',
          code: kAdminWholesalePricesLoadFailed);

  @override
  Future<Result<void>> upsertWholesalePrice({
    required String productId,
    required int priceMinor,
  }) {
    // Client-side guard (batch1 pattern): reject blank ids and
    // non-positive prices before the RPC so typos fail fast with the
    // same boundary code instead of a server round-trip.
    if (productId.trim().isEmpty || priceMinor <= 0) {
      return Future.value(const Failure(AppError(
          'Failed to upsert wholesale price',
          code: kAdminWholesalePriceUpsertFailed)));
    }
    return Result.guard<void>(() async {
      await _client.rpc('admin_upsert_wholesale_price', params: {
        'p_product_id': productId,
        'p_price_minor': priceMinor,
      });
    }, 'Failed to upsert wholesale price',
        code: kAdminWholesalePriceUpsertFailed);
  }

  @override
  Future<Result<void>> deleteWholesalePrice(String productId) {
    if (productId.trim().isEmpty) {
      return Future.value(const Failure(AppError(
          'Failed to delete wholesale price',
          code: kAdminWholesalePriceDeleteFailed)));
    }
    return Result.guard<void>(() async {
      await _client.rpc('admin_delete_wholesale_price', params: {
        'p_product_id': productId,
      });
    }, 'Failed to delete wholesale price',
        code: kAdminWholesalePriceDeleteFailed);
  }
}

/// Maps one `wholesale_price_lists` row (with the `products(name)`
/// embed) into an [AdminWholesalePriceEntry]. Returns null for id-less
/// rows — the list skips them instead of one malformed row failing the
/// whole fetch. A missing product embed falls back to the id so the
/// row stays editable.
AdminWholesalePriceEntry? _entryFromRow(Map<String, dynamic> row) {
  final productId = optString(row, 'product_id');
  if (productId == null || productId.isEmpty) return null;
  final productEmbed = row['products'];
  final productName = productEmbed is Map<String, dynamic>
      ? (optString(productEmbed, 'name') ?? productId)
      : productId;
  return AdminWholesalePriceEntry(
    productId: productId,
    productName: productName,
    priceMinor: optInt(row, 'price_minor') ?? 0,
    updatedAt: safeDateTime(row, 'updated_at'),
  );
}
