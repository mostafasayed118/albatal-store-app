// Canonical route paths for the app router.
//
// Single source of truth: navigation call sites reference these
// constants instead of raw string literals so a typo fails at compile
// time instead of surfacing as a broken route at runtime.
//
// Route *patterns* (with `:id` segments) stay declared in
// app_router.dart; parametrized destinations go through the static
// factory methods below.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const categories = '/categories';
  static const catalog = '/catalog';
  static const wishlist = '/wishlist';
  static const cart = '/cart';
  static const profile = '/profile';
  static const orders = '/profile/orders';
  static const addresses = '/profile/addresses';
  static const settings = '/settings';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const checkout = '/checkout';
  static const paymentMethod = '/payment-method';
  static const paymobCheckout = '/paymob-checkout';
  static const instapayInstructions = '/instapay-instructions';
  static const orderSuccess = '/order-success';
  static const support = '/support';
  static const terms = '/terms';
  static const shippingPolicy = '/shipping-policy';
  static const returnsPolicy = '/returns-policy';
  static const privacyPolicy = '/privacy-policy';
  static const admin = '/admin';
  static const adminCatalog = '/admin/catalog';
  static const adminProductNew = '/admin/products/new';
  static const adminProducts = '/admin/products';
  static const adminCategories = '/admin/categories';
  static const adminOrders = '/admin/orders';
  static const adminInventory = '/admin/inventory';
  // Feature-batch §9/§14 + §13 surfaces (merged locally with the batch).
  static const adminReviews = '/admin/reviews';
  static const adminCustomers = '/admin/customers';
  // Read-only sales dashboard (#12).
  static const adminSales = '/admin/sales';
  static const maintenance = '/maintenance';

  /// Product details for [id].
  ///
  /// The id segment is percent-encoded by the builder itself so call sites
  /// can never forget it: the inbound deep-link path (see `app.dart`) feeds
  /// user/externally-controlled ids straight through, and a raw id with a
  /// `/` or `?` would otherwise be re-interpreted as route structure.
  /// Encoding an ordinary UUID is a no-op.
  static String product(String id) => '/product/${Uri.encodeComponent(id)}';

  /// Catalog with an optional search [query] (`/catalog?q=…`).
  ///
  /// Used by the deep-link handler so the query string can never be built
  /// with a stale literal.
  static String catalogWithQuery(String? query) {
    final trimmed = query?.trim() ?? '';
    if (trimmed.isEmpty) return catalog;
    return '$catalog?q=${Uri.encodeComponent(trimmed)}';
  }

  /// Admin product edit page for [id].
  static String adminProduct(String id) =>
      '/admin/products/${Uri.encodeComponent(id)}';

  /// Admin order detail page for [id].
  static String adminOrder(String id) =>
      '/admin/orders/${Uri.encodeComponent(id)}';

  /// Admin variant editor for [id].
  static String adminVariant(String id) =>
      '/admin/variants/${Uri.encodeComponent(id)}';

  /// Admin image manager for [id].
  static String adminImage(String id) =>
      '/admin/images/${Uri.encodeComponent(id)}';
}
