/// Persisted recent catalog searches (feature-batch §7).
///
/// Domain port (audit 2026-09-13): the presentation cubit depends on
/// this interface; the SharedPreferences implementation stays in the
/// data layer (`data/recent_searches_store.dart`).
abstract interface class RecentSearchesStore {
  List<String> load();

  /// Records [query] at the front, deduped case-insensitively, capped.
  void record(String query);

  void clear();
}
