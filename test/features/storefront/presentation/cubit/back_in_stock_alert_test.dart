import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/memory_storefront_persistence.dart';

/// In-memory [BackInStockAlertStore] fake — no SharedPreferences needed.
final class _MemAlertStore implements BackInStockAlertStore {
  Set<String> watched = {};

  @override
  Set<String> get watchedProductIds => {...watched};

  @override
  bool isWatched(String productId) => watched.contains(productId);

  @override
  void setWatched(String productId, bool enabled) =>
      enabled ? watched.add(productId) : watched.remove(productId);
}

Product _product(String id, {required bool inStock}) => Product(
      id: id,
      name: 'Fabric $id',
      category: 'Silk',
      price: const Money.egp(100),
      imageColor: 0xFF176B57,
      stock: inStock ? const {'Emerald-1m': 3} : const <String, int>{},
    );

void main() {
  late MemoryStorefrontPersistence store;
  late _MemAlertStore alertStore;
  late WishlistCubit cubit;
  late List<Product> restockEvents;

  setUp(() async {
    store = MemoryStorefrontPersistence()..wishlistIds = {'p1'};
    alertStore = _MemAlertStore();
    cubit = WishlistCubit(store, alertStore: alertStore);
    restockEvents = <Product>[];
    cubit.restockAlerts.listen(restockEvents.add);
    // Seed wishlist ids so resolveProducts matches 'p1'.
    await cubit.restore();
  });

  tearDown(() async => cubit.close());

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  group('back-in-stock alert toggle', () {
    test('toggle ON registers the product id in the preset store', () {
      cubit.toggleBackInStockAlert('p1', true);
      expect(cubit.state.alertIds, contains('p1'));
      expect(alertStore.isWatched('p1'), isTrue);
      expect(cubit.isBackInStockWatched('p1'), isTrue);
    });

    test('toggle OFF removes the product id from the preset store', () {
      cubit.toggleBackInStockAlert('p1', true);
      cubit.toggleBackInStockAlert('p1', false);
      expect(cubit.state.alertIds, isNot(contains('p1')));
      expect(alertStore.isWatched('p1'), isFalse);
    });

    test('alertIds are restored from the preset store on restore()', () async {
      alertStore.watched = {'p1'};
      await cubit.restore();
      expect(cubit.state.alertIds, contains('p1'));
    });

    test('removing a wishlist item also unwatches its alert', () {
      cubit.toggleBackInStockAlert('p1', true);
      cubit.toggle('p1'); // remove from wishlist
      expect(cubit.state.alertIds, isNot(contains('p1')));
      expect(alertStore.isWatched('p1'), isFalse);
    });
  });

  group('restock gating logic', () {
    test(
        'out-of-stock -> in-stock transition fires exactly one alert for a '
        'watched product', () async {
      cubit.toggleBackInStockAlert('p1', true);
      cubit.resolveProducts([_product('p1', inStock: false)]);
      cubit.resolveProducts([_product('p1', inStock: true)]);
      await tick();
      expect(restockEvents, hasLength(1));
      expect(restockEvents.single.id, 'p1');

      // A repeated resolution of the same in-stock state must not
      // re-fire — the transition already reported.
      cubit.resolveProducts([_product('p1', inStock: true)]);
      await tick();
      expect(restockEvents, hasLength(1));
    });

    test('no alert for unwatched products', () async {
      cubit.resolveProducts([_product('p1', inStock: false)]);
      cubit.resolveProducts([_product('p1', inStock: true)]);
      await tick();
      expect(restockEvents, isEmpty);
    });

    test('no alert on the first resolution (never observed out of stock)',
        () async {
      cubit.toggleBackInStockAlert('p1', true);
      cubit.resolveProducts([_product('p1', inStock: true)]);
      await tick();
      expect(restockEvents, isEmpty);
    });

    test('no alert while the product stays out of stock', () async {
      cubit.toggleBackInStockAlert('p1', true);
      cubit.resolveProducts([_product('p1', inStock: false)]);
      cubit.resolveProducts([_product('p1', inStock: false)]);
      await tick();
      expect(restockEvents, isEmpty);
    });
  });
}
