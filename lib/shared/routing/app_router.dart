import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../services/navigation_observer.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';
import 'auth_refresh_notifier.dart';
import 'route_pages.dart';

GoRouter createAppRouter(
  AuthCubit authCubit, {
  String initialLocation = Routes.splash,
  AuthRefreshNotifier? refreshListenable,
}) =>
    GoRouter(
      initialLocation: initialLocation,
      observers: [NavigationObserver()],
      refreshListenable:
          refreshListenable ?? AuthRefreshNotifier(authCubit.stream),
      redirect: (_, state) => authRedirect(
        isAuthenticated: authCubit.state.isAuthenticated,
        isAdmin: authCubit.state.profile?.isAdmin == true,
        path: state.uri.path,
      ),
      routes: _routes,
    );

/// The route table: paths, structure and delegation only. Page
/// construction (service location, pre-DI test affordances, argument
/// parsing) lives in [RoutePages]; the auth policy lives in
/// `auth_redirect.dart` (audit 2026-09-21, P2 slim-down — this file was
/// a 374-line mix of all three).
final _routes = <RouteBase>[
  GoRoute(path: Routes.splash, builder: (_, __) => RoutePages.splash()),
  GoRoute(path: Routes.onboarding, builder: (_, __) => RoutePages.onboarding()),
  ShellRoute(builder: (_, __, child) => RoutePages.appShell(child), routes: [
    GoRoute(path: Routes.home, builder: (_, __) => RoutePages.home()),
    GoRoute(
        path: Routes.categories, builder: (_, __) => RoutePages.categories()),
    GoRoute(path: Routes.catalog, builder: (_, s) => RoutePages.catalog(s)),
    GoRoute(path: Routes.wishlist, builder: (_, __) => RoutePages.wishlist()),
    GoRoute(path: Routes.cart, builder: (_, __) => RoutePages.cart()),
    GoRoute(path: Routes.profile, builder: (_, __) => RoutePages.profile()),
  ]),
  GoRoute(
    // Literal `:id` pattern (NOT the factory — `Uri.encodeComponent`
    // would turn `:id` into `%3Aid`, a static segment that matches
    // nothing; caught by `every admin route resolves`).
    path: Routes.productDetail,
    builder: (_, s) => RoutePages.productDetail(s),
  ),
  GoRoute(path: Routes.checkout, builder: (_, __) => RoutePages.checkout()),
  GoRoute(
      path: Routes.orderSuccess, builder: (_, s) => RoutePages.orderSuccess(s)),
  GoRoute(path: Routes.orders, builder: (_, __) => RoutePages.orders()),
  GoRoute(path: Routes.addresses, builder: (_, __) => RoutePages.addresses()),
  GoRoute(
    path: Routes.settings,
    // The shared adapter resolves the app-scoped cubits from this route
    // builder's context (inside its callbacks — no rebuilds needed).
    builder: (context, __) => RoutePages.settings(context),
  ),
  GoRoute(path: Routes.signIn, builder: (_, __) => RoutePages.signIn()),
  GoRoute(path: Routes.signUp, builder: (_, __) => RoutePages.signUp()),
  GoRoute(
      path: Routes.forgotPassword,
      builder: (_, __) => RoutePages.forgotPassword()),
  GoRoute(
      path: Routes.resetPassword,
      builder: (_, __) => RoutePages.resetPassword()),
  GoRoute(
      path: Routes.paymentMethod,
      builder: (_, s) => RoutePages.paymentMethod(s)),
  GoRoute(
      path: Routes.paymobCheckout,
      builder: (_, s) => RoutePages.paymobCheckout(s)),
  GoRoute(
    path: Routes.instapayInstructions,
    // No path change (router review gate): the shared PaymentCubit
    // stays load-bearing via `extra['cubit']`; `extra['orderId']` is
    // carried additively for the page's rehydration path.
    builder: (_, s) => RoutePages.instapayInstructions(s),
  ),
  GoRoute(path: Routes.admin, builder: (_, __) => RoutePages.adminDashboard()),
  GoRoute(
      path: Routes.adminOrders, builder: (_, __) => RoutePages.adminOrders()),
  GoRoute(
      path: Routes.adminReviews, builder: (_, __) => RoutePages.adminReviews()),
  GoRoute(
      path: Routes.maintenance, builder: (_, __) => RoutePages.maintenance()),
  GoRoute(
      path: Routes.adminCustomers,
      builder: (_, __) => RoutePages.adminCustomers()),
  GoRoute(
      path: Routes.adminCoupons, builder: (_, __) => RoutePages.adminCoupons()),
  GoRoute(
    path: Routes.adminOrderDetail, // literal pattern (see Routes.productDetail)
    builder: (_, s) => RoutePages.adminOrderDetail(s),
  ),
  GoRoute(
    path: Routes.adminInventory,
    builder: (_, __) => RoutePages.adminInventory(),
  ),
  GoRoute(
      path: Routes.adminCatalog, builder: (_, __) => RoutePages.adminCatalog()),
  GoRoute(path: Routes.adminSales, builder: (_, __) => RoutePages.adminSales()),
  // Catalog management destinations (migration-era hub tiles pointed at
  // these paths, but the routes themselves were never registered — every
  // tile dead-ended on "Page Not Found").
  GoRoute(
    path: Routes.adminProducts,
    builder: (_, __) => RoutePages.adminProducts(),
  ),
  GoRoute(
    path: Routes.adminProductNew,
    builder: (_, __) => RoutePages.adminProductNew(),
  ),
  GoRoute(
    path: Routes.adminProductEdit,
    builder: (_, s) => RoutePages.adminProductEdit(s),
  ),
  GoRoute(
    path: Routes.adminCategories,
    builder: (_, __) => RoutePages.adminCategories(),
  ),
  GoRoute(
    path: Routes.adminImages,
    builder: (_, s) => RoutePages.adminImages(s),
  ),
  GoRoute(
    path: Routes.adminVariantEdit, // literal pattern
    builder: (_, s) => RoutePages.adminVariantEdit(s),
  ),
  GoRoute(path: Routes.support, builder: (_, __) => RoutePages.support()),
  GoRoute(
      path: Routes.privacyPolicy,
      builder: (_, __) => RoutePages.privacyPolicy()),
  GoRoute(path: Routes.terms, builder: (_, __) => RoutePages.terms()),
  GoRoute(
    path: Routes.shippingPolicy,
    builder: (_, __) => RoutePages.shippingPolicy(),
  ),
  GoRoute(
    path: Routes.returnsPolicy,
    builder: (_, __) => RoutePages.returnsPolicy(),
  ),
];
