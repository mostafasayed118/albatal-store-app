import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  blocTest<CartCubit, CartState>(
    'merges matching configured products and calculates totals',
    build: () => CartCubit(MemoryStorefrontPersistence()),
    act: (cubit) {
      cubit.add(products.first, color: 'Emerald', length: '2m');
      cubit.add(products.first, color: 'Emerald', length: '2m');
    },
    expect: () => [
      CartState([CartItem(product: products.first, color: 'Emerald', length: '2m')],
          status: CartStatus.ready),
      CartState([CartItem(product: products.first, color: 'Emerald', length: '2m', quantity: 2)],
          status: CartStatus.ready),
    ],
    verify: (cubit) => expect(cubit.state.total, 2655),
  );

  test('restores configured cart lines and wishlist ids from local storage', () async {
    final storage = MemoryStorefrontPersistence();
    final sourceCart = CartCubit(storage);
    final sourceWishlist = WishlistCubit(storage);

    sourceCart.add(products.first, color: 'Emerald', length: '3m', quantity: 2);
    sourceWishlist.toggle(products.last.id);

    final restoredCart = CartCubit(storage);
    final restoredWishlist = WishlistCubit(storage);
    await restoredCart.restore();
    await restoredWishlist.restore();

    expect(restoredCart.state.items, [CartItem(product: products.first, color: 'Emerald', length: '3m', quantity: 2)]);
    expect(restoredWishlist.state.ids, {products.last.id});
    await sourceCart.close();
    await sourceWishlist.close();
    await restoredCart.close();
    await restoredWishlist.close();
  });
}
