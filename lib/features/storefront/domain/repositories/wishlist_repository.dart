import '../../../../core/error/result.dart';

/// Abstraction for wishlist persistence.
///
/// Lives in the domain layer so the presentation Cubit never imports
/// from data. The data layer provides the concrete implementation.
/// Returns [Result] so callers receive errors at this boundary.
abstract interface class WishlistRepository {
  Future<Result<Set<String>>> readWishlist();
  Future<Result<void>> writeWishlist(Set<String> ids);
}
