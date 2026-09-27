/// Server half of wishlist sync (migration 075).
///
/// Thin port over the `sync_wishlist` RPC so the repository stays
/// unit-testable: widget/unit tests inject a recording fake instead of
/// mocking the Supabase client.
abstract interface class WishlistSyncRemote {
  /// Union-merges [localIds] into the server set and returns the merged
  /// ids. Throws on transport/auth failure — the repository decides the
  /// fallback (local list), never this port.
  Future<Set<String>> syncWishlist(Set<String> localIds);
}
