import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Supabase-backed wishlist repository.
class SupabaseWishlistRepository implements WishlistRepository {
  SupabaseWishlistRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _user => _client.auth.currentUser!;

  @override
  Future<Set<String>> readWishlist() async {
    final response = await _client
        .from('wishlists')
        .select('product_id')
        .eq('user_id', _user.id);

    return (response as List)
        .map((row) => row['product_id'] as String)
        .toSet();
  }

  @override
  Future<void> writeWishlist(Set<String> ids) async {
    await _client.from('wishlists').delete().eq('user_id', _user.id);

    if (ids.isNotEmpty) {
      final rows = ids
          .map((id) => {
                'user_id': _user.id,
                'product_id': id,
              })
          .toList();
      await _client.from('wishlists').insert(rows);
    }
  }
}
