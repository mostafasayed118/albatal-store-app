import 'dart:convert';

import 'package:al_batal_elite/features/storefront/data/catalog_persistent_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-only SharedPreferences double that hands back a fixed payload.
final class _StubCatalogPrefs extends Fake implements SharedPreferences {
  _StubCatalogPrefs(this.values);

  final Map<String, String?> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

/// One corrupt cache entry must not discard the whole snapshot: the bad row
/// is skipped (logged) and its healthy neighbours survive.
void main() {
  test('a corrupt entry is skipped and the healthy ones survive', () async {
    final prefs = _StubCatalogPrefs({
      catalogPersistentCacheKey: jsonEncode([
        // Negative price trips the Money invariant → the entry throws.
        {'id': 'p1', 'name': 'Broken Row', 'price': -5},
        {'id': 'p2', 'name': 'Healthy Row', 'price': 100},
      ]),
    });

    final restored = await restoreCatalogCache(prefs);

    expect(restored, isNotNull);
    expect(restored, hasLength(1));
    expect(restored!.single.id, 'p2');
    expect(restored.single.name, 'Healthy Row');
  });
}
