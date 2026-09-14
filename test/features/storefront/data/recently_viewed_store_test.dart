import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/recently_viewed_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PrefsRecentlyViewedStore store;
  late SharedPreferences prefs;

  const silk = Product(
    id: 'p-silk',
    name: 'Silk Charmeuse',
    category: 'Silk',
    price: Money.egp(1290),
    imageColor: 0xFF004D40,
  );
  const linen = Product(
    id: 'p-linen',
    name: 'Linen',
    category: 'Linen',
    price: Money.egp(550),
    imageColor: 0xFF8D6E63,
    imageAsset: 'assets/linen.png',
    oldPrice: Money.egp(700),
    rating: 4.5,
    reviewCount: 12,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PrefsRecentlyViewedStore(prefs);
  });

  test('empty store loads empty list', () {
    expect(store.load(), isEmpty);
  });

  test('records most-recent-first', () {
    store.record(silk);
    store.record(linen);
    expect(store.load().map((p) => p.id), ['p-linen', 'p-silk']);
  });

  test('round-trips price, image and rating through the snapshot', () {
    store.record(linen);
    final loaded = store.load().single;
    expect(loaded, linen);
  });

  test('dedupes by id, refreshing position', () {
    store.record(silk);
    store.record(linen);
    store.record(silk);
    expect(store.load().map((p) => p.id), ['p-silk', 'p-linen']);
  });

  test('caps at $kRecentlyViewedMax entries', () {
    for (var i = 0; i < kRecentlyViewedMax + 5; i++) {
      store.record(Product(
        id: 'p-$i',
        name: 'p$i',
        category: 'c',
        price: Money.egp(i + 1),
        imageColor: 0xFF000000,
      ));
    }
    final loaded = store.load();
    expect(loaded.length, kRecentlyViewedMax);
    expect(loaded.first.id, 'p-${kRecentlyViewedMax + 4}');
  });

  test('total-decode: malformed entries are skipped, never thrown', () {
    prefs.setStringList(kRecentlyViewedKey, [
      'not-json',
      '{"id":""}',
      '{"id":"ok","name":"N","category":"C","price_minor":100}'
    ]);
    final loaded = store.load();
    expect(loaded.single.id, 'ok');
  });

  test('persists across store instances', () {
    store.record(silk);
    expect(PrefsRecentlyViewedStore(prefs).load().single.id, silk.id);
  });

  test('clear empties the store', () {
    store.record(silk);
    store.clear();
    expect(store.load(), isEmpty);
  });
}
