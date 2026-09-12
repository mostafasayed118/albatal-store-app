import 'package:al_batal_elite/features/storefront/data/recent_searches_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PrefsRecentSearchesStore store;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PrefsRecentSearchesStore(prefs);
  });

  test('empty store loads empty list', () {
    expect(store.load(), isEmpty);
  });

  test('records most-recent-first and trims whitespace', () {
    store.record('  silk  ');
    store.record('wool');
    expect(store.load(), ['wool', 'silk']);
  });

  test('dedupes case-insensitively, refreshing position', () {
    store.record('Silk');
    store.record('wool');
    store.record('  silk ');
    expect(store.load(), ['silk', 'wool']);
  });

  test('caps at $kRecentSearchesMax entries', () {
    for (var i = 0; i < kRecentSearchesMax + 5; i++) {
      store.record('query-$i');
    }
    final loaded = store.load();
    expect(loaded.length, kRecentSearchesMax);
    expect(loaded.first, 'query-${kRecentSearchesMax + 4}');
  });

  test('blank queries are ignored', () {
    store.record('   ');
    expect(store.load(), isEmpty);
  });

  test('persists across store instances', () {
    store.record('silk');
    final second = PrefsRecentSearchesStore(prefs);
    expect(second.load(), ['silk']);
  });

  test('clear empties the store', () {
    store.record('silk');
    store.clear();
    expect(store.load(), isEmpty);
  });
}
