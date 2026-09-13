import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recently_viewed_store.dart';

/// Test-only in-memory [RecentlyViewedStore] for harnesses that pump
/// pages reading the app-scoped [RecentlyViewedCubit].
final class MemoryRecentlyViewedStore implements RecentlyViewedStore {
  final List<Product> entries = [];

  @override
  List<Product> load() => List.of(entries);

  @override
  void record(Product product) {
    entries.removeWhere((e) => e.id == product.id);
    entries.insert(0, product);
  }

  @override
  void clear() => entries.clear();
}
