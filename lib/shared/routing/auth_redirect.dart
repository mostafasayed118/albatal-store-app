import 'app_routes.dart';

/// The authentication redirect policy (audit 2026-09-21, P2): extracted
/// from `app_router.dart` as a pure, path-based function so it can be
/// unit-tested with nothing but a path and two booleans — no GoRouter
/// state, no router instance, no cubit.
///
/// Policy:
///  * every `/admin…` route requires an authenticated admin — an
///    anonymous visitor is sent to sign-in with a redirect back, a
///    signed-in non-admin is bounced to home;
///  * checkout and post-purchase/account routes require a session;
///  * cart is intentionally public — a guest must be able to review the
///    cart they are building; the auth gate moves to checkout (UI/UX
///    review P0 funnel fix);
///  * everything else is public.
String? authRedirect({
  required bool isAuthenticated,
  required bool isAdmin,
  required String path,
}) {
  String signInRedirect(String target) =>
      Uri(path: Routes.signIn, queryParameters: {'redirect': target})
          .toString();

  bool matchesAuthRoute(String route) =>
      path == route || path.startsWith('$route/');

  if (matchesAuthRoute(Routes.admin)) {
    if (!isAuthenticated) return signInRedirect(path);
    if (!isAdmin) return Routes.home;
    return null;
  }

  // Checkout and post-purchase/account screens require a session. Cart is
  // intentionally public — a guest must be able to review the cart they are
  // building; the auth gate moves to checkout (UI/UX review P0 funnel fix).
  const authRequired = [
    Routes.checkout,
    Routes.orders,
    Routes.addresses,
    Routes.wishlist,
    Routes.paymentMethod,
    Routes.paymobCheckout,
    Routes.instapayInstructions,
    Routes.orderSuccess,
  ];
  if (authRequired.any(matchesAuthRoute) && !isAuthenticated) {
    return signInRedirect(path);
  }
  return null;
}
