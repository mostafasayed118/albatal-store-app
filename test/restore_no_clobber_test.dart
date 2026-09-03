// ============================================================
// Anti-clobber restore tests (live-found 2026-09-03).
//
// Startup restore()/load() reads are async. If the user acts
// before a stale read completes, the late result must NOT
// overwrite live state — the server was once sent a stale
// product and a stale address snapshot this way.
// Rule: restore applies only to pristine (empty) state unless
// forced (explicit manual refresh).
// ============================================================

import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/products_data.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wishlist_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _CartRepo implements CartRepository {
  _CartRepo(this.itemsToReturn);
  List<CartItem> itemsToReturn;

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      Success(itemsToReturn);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async =>
      const Success(null);
}

class _AddressRepo implements AddressRepository {
  _AddressRepo(this.addressesToReturn);
  List<Address> addressesToReturn;

  @override
  Future<Result<List<Address>>> read() async => Success(addressesToReturn);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

class _WishlistRepo implements WishlistRepository {
  _WishlistRepo(this.idsToReturn);
  Set<String> idsToReturn;

  @override
  Future<Result<Set<String>>> readWishlist() async => Success(idsToReturn);

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async =>
      const Success(null);
}

const _staleAddress = Address(
  id: 'stale-1',
  recipient: 'Stale',
  line: 'Old St',
  city: 'Old City',
  country: 'EG',
);

const _freshAddress = Address(
  id: 'fresh-1',
  recipient: 'Fresh',
  line: 'New St',
  city: 'New City',
  country: 'EG',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('restore/load never clobbers live state', () {
    test('late cart restore keeps live items', () async {
      final repo = _CartRepo([]);
      final cubit = CartCubit(repo);
      await cubit.restore();
      expect(cubit.state.items, isEmpty);

      // User acts: fresh item added (and persisted).
      cubit.add(products.first, color: 'Gold', length: '2m');

      // A stale read completes late (e.g. previous install's cart).
      repo.itemsToReturn = [
        CartItem(
            product: products.last, color: 'Blue', length: '1m', quantity: 1),
      ];
      await cubit.restore();

      expect(
        cubit.state.items.map((i) => i.product.id),
        [products.first.id],
        reason: 'stale restore must not replace the live cart',
      );
      expect(cubit.state.items.single.color, 'Gold');

      await cubit.close();
    });

    test('forced cart restore applies (manual refresh)', () async {
      final repo = _CartRepo([]);
      final cubit = CartCubit(repo);
      await cubit.restore();
      cubit.add(products.first);

      repo.itemsToReturn = [
        CartItem(product: products.last, color: 'Blue', length: '1m')
      ];
      await cubit.restore(force: true);

      expect(
        cubit.state.items.map((i) => i.product.id),
        [products.last.id],
      );

      await cubit.close();
    });

    test('late addresses load keeps the live book', () async {
      final repo = _AddressRepo([]);
      final cubit = AddressesCubit(repo);
      await cubit.load();
      await cubit.upsert(_freshAddress);
      expect(cubit.state.addresses.map((a) => a.id), ['fresh-1']);

      // Stale read completes late.
      repo.addressesToReturn = [_staleAddress];
      await cubit.load();

      expect(
        cubit.state.addresses.map((a) => a.id),
        ['fresh-1'],
        reason: 'stale load must not replace the live address book',
      );

      await cubit.close();
    });

    test('forced addresses load applies (manual refresh)', () async {
      final repo = _AddressRepo([]);
      final cubit = AddressesCubit(repo);
      await cubit.load();
      await cubit.upsert(_freshAddress);

      repo.addressesToReturn = [_staleAddress];
      await cubit.load(force: true);

      expect(cubit.state.addresses.map((a) => a.id), ['stale-1']);

      await cubit.close();
    });

    test('late wishlist restore keeps live ids', () async {
      final repo = _WishlistRepo({});
      final cubit = WishlistCubit(repo);
      await cubit.restore();
      cubit.toggle(products.first.id);

      // Stale read completes late.
      repo.idsToReturn = {products.last.id};
      await cubit.restore();

      expect(cubit.state.ids, {products.first.id},
          reason: 'stale restore must not replace the live wishlist');

      await cubit.close();
    });
  });
}
