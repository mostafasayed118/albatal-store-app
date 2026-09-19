import '../../../core/error/result.dart';

/// Account-deletion operations consumed by the settings feature (UX-043).
///
/// Cross-feature port (audit 2026-09): [SettingsPage] must not import the
/// auth or storefront *presentation* layers (`AuthCubit`, `CartCubit`,
/// `WishlistCubit`), so it depends on this narrow domain abstraction
/// instead — the same port pattern as `OrderSnapshotPort` /
/// `AuthSessionPort`. The app-scoped adapter (`SettingsAccountAdapter`)
/// lives in `lib/shared/` and is composed in `app_router.dart`; its cubit
/// reads happen inside route-builder callbacks so no widget rebuilds.
abstract interface class AccountDeletionPort {
  /// Whether a signed-in session exists (gates the destructive row).
  bool get isAuthenticated;

  /// Permanently deletes the account; the server verifies [email].
  Future<Result<void>> deleteAccount({required String email});

  /// Wipes on-device guest-accessible user data (cart + wishlist) after a
  /// successful deletion so it cannot survive the deleted account.
  void clearGuestData();
}
