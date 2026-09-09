import '../../../core/error/result.dart';
import '../domain/repositories/wishlist_repository.dart';
import 'storefront_persistence.dart';

/// Data-layer implementation of [WishlistRepository].
///
/// Catches errors at the boundary so the Cubit only sees [Result].
final class LocalWishlistRepository implements WishlistRepository {
  LocalWishlistRepository(this._persistence);
  final LocalStorefrontPersistence _persistence;

  @override
  Future<Result<Set<String>>> readWishlist() => Result.guard(
      () => _persistence.readWishlist(), 'Failed to load wishlist');

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) => Result.guard<void>(
        () => _persistence.writeWishlist(ids),
        'Failed to save wishlist',
      );
}
