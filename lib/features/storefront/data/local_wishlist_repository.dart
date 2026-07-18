import '../domain/repositories/wishlist_repository.dart';
import 'storefront_persistence.dart';

/// Data-layer implementation of [WishlistRepository].
final class LocalWishlistRepository implements WishlistRepository {
  LocalWishlistRepository(this._persistence);
  final StorefrontPersistence _persistence;

  @override
  Future<Set<String>> readWishlist() => _persistence.readWishlist();

  @override
  Future<void> writeWishlist(Set<String> ids) =>
      _persistence.writeWishlist(ids);
}
