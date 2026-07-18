/// Abstraction for wishlist persistence.
///
/// Lives in the domain layer so the presentation Cubit never imports
/// from data. The data layer provides the concrete implementation.
abstract interface class WishlistRepository {
  Future<Set<String>> readWishlist();
  Future<void> writeWishlist(Set<String> ids);
}
