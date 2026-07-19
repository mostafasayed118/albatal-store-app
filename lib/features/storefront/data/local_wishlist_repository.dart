import '../../../core/error/app_error.dart';
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
  Future<Result<Set<String>>> readWishlist() async {
    try {
      return Success(await _persistence.readWishlist());
    } catch (e) {
      return Failure(AppError('Failed to load wishlist', cause: e));
    }
  }

  @override
  Future<Result<void>> writeWishlist(Set<String> ids) async {
    try {
      await _persistence.writeWishlist(ids);
      return const Success(null);
    } catch (e) {
      return Failure(AppError('Failed to save wishlist', cause: e));
    }
  }
}
