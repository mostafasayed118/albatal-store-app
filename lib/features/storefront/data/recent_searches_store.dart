import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/recent_searches_store.dart';

const kRecentSearchesKey = 'recent_searches_v1';
const kRecentSearchesMax = 10;

/// SharedPreferences-backed store. Most-recent-first, deduped
/// case-insensitively (so "Silk" and "silk" collapse), capped at
/// [kRecentSearchesMax] entries.
final class PrefsRecentSearchesStore implements RecentSearchesStore {
  PrefsRecentSearchesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  List<String> load() =>
      List<String>.from(_prefs.getStringList(kRecentSearchesKey) ?? const []);

  @override
  void record(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = load();
    current.removeWhere(
        (existing) => existing.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    _prefs.setStringList(
        kRecentSearchesKey, current.take(kRecentSearchesMax).toList());
  }

  @override
  void clear() => _prefs.remove(kRecentSearchesKey);
}
