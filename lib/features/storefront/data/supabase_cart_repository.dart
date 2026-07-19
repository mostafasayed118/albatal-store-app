import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';

/// Supabase-backed cart repository.
///
/// Stores cart items per authenticated user. Each item references
/// a variant_id (size+color combination) and a quantity.
class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _user => _client.auth.currentUser!;

  @override
  Future<List<CartItem>> readCart(ProductLookup productForId) async {
    final response = await _client
        .from('cart_items')
        .select('*, product_variants(*, products(*))')
        .eq('user_id', _user.id);

    return (response as List).map((row) {
      final variant = row['product_variants'];
      final product = variant['products'];
      return CartItem(
        product: Product(
          id: product['id'] as String,
          name: product['name'] as String,
          category: '',
          price: Money((variant['price_override'] as int?) ??
              (product['base_price'] as int)),
          imageColor: 0xFF176B57,
        ),
        color: variant['color'] as String,
        length: variant['size'] as String,
        quantity: row['quantity'] as int,
      );
    }).toList();
  }

  @override
  Future<void> writeCart(List<CartItem> items) async {
    // Delete existing cart items
    await _client.from('cart_items').delete().eq('user_id', _user.id);

    // Insert new cart items
    if (items.isNotEmpty) {
      final rows = items
          .map((item) => {
                'user_id': _user.id,
                'variant_id': item.product.id,
                'quantity': item.quantity,
              })
          .toList();
      await _client.from('cart_items').insert(rows);
    }
  }
}
