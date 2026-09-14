import '../../../../core/entities/product.dart';

/// Persisted recently-viewed products (#3 feature batch).
///
/// Domain port (mirrors [RecentSearchesStore]): the presentation cubit
/// depends on this interface; the SharedPreferences implementation stays
/// in the data layer (`data/recently_viewed_store.dart`). Snapshots are
/// persisted locally so the home strip renders offline with no extra
/// fetch.
abstract interface class RecentlyViewedStore {
  /// Most-recent-first product snapshots.
  List<Product> load();

  /// Records [product] at the front, deduped by id, capped.
  void record(Product product);

  void clear();
}
