/// Read-only view of the current auth session for checkout.
///
/// Lets the checkout page resolve the customer email without importing
/// Supabase (or any auth implementation) into the presentation layer.
/// Implemented in the auth data layer; null means no signed-in session.
abstract interface class AuthSessionPort {
  /// Returns the signed-in user's email, or null when signed out.
  String? currentUserEmail();
}
