import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/products_data.dart';

final class _DelayedCartRepo implements CartRepository {
  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const Success(<CartItem>[]);
  }

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    return const Success(null);
  }
}

final class _FakeWishlistRepo implements WishlistRepository {
  @override
  Future<Result<Set<String>>> readWishlist() async {
    return const Success(<String>{});
  }

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    return const Success(null);
  }
}

void main() {
  test('restore preserves premium flag set before the read completes',
      () async {
    final cubit = CartCubit(_DelayedCartRepo());
    final restoreFuture = cubit.restore();
    cubit.setPremiumMember(isPremium: true);
    await restoreFuture;
    expect(cubit.state.status, CartStatus.ready);
    expect(cubit.state.isPremiumMember, isTrue);
    await cubit.close();
  });

  test('toggle-off removes only that product without an empty-list emit',
      () async {
    final cubit = WishlistCubit(_FakeWishlistRepo());
    cubit.toggle('silk-01');
    cubit.toggle('cotton-01');
    cubit.resolveProducts(products);
    expect(cubit.state.products.map((p) => p.id),
        containsAll(['silk-01', 'cotton-01']));

    final emissions = <WishlistState>[];
    final sub = cubit.stream.listen(emissions.add);
    cubit.toggle('silk-01');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.ids, {'cotton-01'});
    expect(cubit.state.products.map((p) => p.id), ['cotton-01']);
    expect(emissions, hasLength(1));
    expect(emissions.single.products.map((p) => p.id), ['cotton-01']);
    expect(emissions.where((s) => s.products.isEmpty), isEmpty);
    await sub.cancel();
    await cubit.close();
  });

  test('toggle-on keeps the existing products list identical', () async {
    final cubit = WishlistCubit(_FakeWishlistRepo());
    cubit.toggle('silk-01');
    cubit.toggle('cotton-01');
    cubit.resolveProducts(products);
    final before = List<Product>.of(cubit.state.products);

    cubit.toggle('velvet-01');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.ids, {'silk-01', 'cotton-01', 'velvet-01'});
    expect(cubit.state.products.map((p) => p.id),
        before.map((p) => p.id).toList());
    await cubit.close();
  });
}
