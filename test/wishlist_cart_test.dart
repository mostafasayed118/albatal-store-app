import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/storefront_cubits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wishlist ↔ Cart interactions', () {
    late MemoryStorefrontPersistence store;
    late CartCubit cart;
    late WishlistCubit wishlist;

    setUp(() {
      store = MemoryStorefrontPersistence();
      cart = CartCubit(store);
      wishlist = WishlistCubit(store);
    });

    tearDown(() async {
      await cart.close();
      await wishlist.close();
    });

    test('move to cart: adds product to cart and removes from wishlist', () {
      // Start with product in wishlist.
      wishlist.toggle('silk-01');
      expect(wishlist.state, contains('silk-01'));
      expect(cart.state.items, isEmpty);

      // Move to cart: add to cart + toggle off wishlist.
      final product = products.firstWhere((p) => p.id == 'silk-01');
      cart.add(product);
      wishlist.toggle('silk-01');

      expect(cart.state.items, hasLength(1));
      expect(cart.state.items.first.product.id, 'silk-01');
      expect(wishlist.state, isEmpty);
    });

    test('save for later: adds product to wishlist and removes from cart', () {
      // Start with product in cart.
      cart.add(products.first, color: 'Gold', length: '5m');
      expect(cart.state.items, hasLength(1));
      expect(wishlist.state, isEmpty);

      // Save for later: toggle in wishlist + remove from cart.
      final item = cart.state.items.first;
      wishlist.toggle(item.product.id);
      cart.remove(item.key);

      expect(cart.state.items, isEmpty);
      expect(wishlist.state, contains('silk-01'));
    });

    test('round-trip: wishlist → cart → wishlist preserves product data', () {
      wishlist.toggle('velvet-01');
      expect(wishlist.state, contains('velvet-01'));

      // Move to cart.
      final product = products.firstWhere((p) => p.id == 'velvet-01');
      cart.add(product, color: 'Ivory', length: '1m');
      wishlist.toggle('velvet-01');

      expect(cart.state.items.single.color, 'Ivory');
      expect(cart.state.items.single.length, '1m');

      // Save for later.
      final item = cart.state.items.single;
      wishlist.toggle(item.product.id);
      cart.remove(item.key);

      expect(wishlist.state, contains('velvet-01'));
      expect(cart.state.items, isEmpty);
    });
  });
}
