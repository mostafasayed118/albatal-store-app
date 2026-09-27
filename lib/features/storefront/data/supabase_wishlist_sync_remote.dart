import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/services/logger.dart';
import '../domain/repositories/wishlist_sync_remote.dart';

/// [WishlistSyncRemote] over the `sync_wishlist` RPC (migration 075).
///
/// Before the migration is applied every call throws the Postgrest
/// "function does not exist" error and the repository degrades to the
/// local list — the guest experience is unchanged.
///
/// The response decoder is a top-level pure function so the wire shape
/// is unit-testable without a Supabase stub.
final class SupabaseWishlistSyncRemote implements WishlistSyncRemote {
  SupabaseWishlistSyncRemote({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<Set<String>> syncWishlist(Set<String> localIds) async {
    final response = await _client.rpc('sync_wishlist', params: {
      'p_product_ids': localIds.toList(),
    });
    return parseWishlistIds(response);
  }
}

/// Decodes the `sync_wishlist` UUID[] payload into product-id strings.
///
/// The RPC returns a Postgres array, which supabase-flutter decodes to a
/// `List` of strings. Anything else (null on an unexpected shape,
/// non-string elements, blanks) is dropped — a malformed server payload
/// must never poison the local list.
Set<String> parseWishlistIds(dynamic response) {
  if (response is! List) {
    Log.w('wishlist sync returned unexpected shape; ignoring.');
    return const {};
  }
  return {
    for (final item in response)
      if (item is String && item.isNotEmpty) item,
  };
}
