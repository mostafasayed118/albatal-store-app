import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
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
      wishlist.toggle('silk-01');
      expect(wishlist.state.ids, contains('silk-01'));
      expect(cart.state.items, isEmpty);

      final product = products.firstWhere((p) => p.id == 'silk-01');
      cart.add(product);
      wishlist.toggle('silk-01');

      expect(cart.state.items, hasLength(1));
      expect(cart.state.items.first.product.id, 'silk-01');
      expect(wishlist.state.ids, isEmpty);
    });

    test('save for later: adds product to wishlist and removes from cart', () {
      cart.add(products.first, color: 'Gold', length: '5m');
      expect(cart.state.items, hasLength(1));
      expect(wishlist.state.ids, isEmpty);

      final item = cart.state.items.first;
      wishlist.toggle(item.product.id);
      cart.remove(item.key);

      expect(cart.state.items, isEmpty);
      expect(wishlist.state.ids, contains('silk-01'));
    });

    test('round-trip: wishlist → cart → wishlist preserves product data', () {
      wishlist.toggle('velvet-01');
      expect(wishlist.state.ids, contains('velvet-01'));

      final product = products.firstWhere((p) => p.id == 'velvet-01');
      cart.add(product, color: 'Ivory', length: '1m');
      wishlist.toggle('velvet-01');

      expect(cart.state.items.single.color, 'Ivory');
      expect(cart.state.items.single.length, '1m');

      final item = cart.state.items.single;
      wishlist.toggle(item.product.id);
      cart.remove(item.key);

      expect(wishlist.state.ids, contains('velvet-01'));
      expect(cart.state.items, isEmpty);
    });
  });
}
