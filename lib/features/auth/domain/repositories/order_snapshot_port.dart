/// Device-local order-snapshot wipe port (audit S9).
///
/// Lets [AuthCubit] clear the on-device order history on sign-out and
/// account deletion without importing the storefront data layer.
/// Server orders are unaffected — implementations only clear the legacy
/// on-device snapshot.
abstract interface class OrderSnapshotPort {
  /// Deletes the local order-history snapshot.
  Future<void> clearOrderSnapshots();
}
