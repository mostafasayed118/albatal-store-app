import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_categories_page.dart';
import '../../features/admin/presentation/pages/admin_catalog_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_image_manager_page.dart';
import '../../features/admin/presentation/pages/admin_inventory_page.dart';
import '../../features/admin/presentation/pages/admin_order_detail_page.dart';
import '../../features/admin/presentation/pages/admin_orders_page.dart';
import '../../features/admin/presentation/pages/admin_product_edit_page.dart';
import '../../features/admin/presentation/pages/admin_products_page.dart';
import '../../features/admin/presentation/pages/admin_variant_editor_page.dart';
import '../../features/addresses/presentation/pages/addresses_page.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/payments/presentation/cubit/payment_cubit.dart';
import '../../features/payments/presentation/pages/instapay_instructions_page.dart';
import '../../features/payments/presentation/pages/payment_method_page.dart';
import '../../features/payments/presentation/pages/paymob_checkout_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/storefront/presentation/pages/cart_page.dart';
import '../../features/storefront/presentation/pages/catalog_page.dart';
import '../../features/storefront/presentation/pages/categories_page.dart';
import '../../features/storefront/presentation/pages/checkout_page.dart';
import '../../features/storefront/presentation/pages/details_page.dart';
import '../../features/storefront/presentation/pages/home_page.dart';
import '../../features/storefront/presentation/pages/order_success_page.dart';
import '../../features/storefront/presentation/pages/orders_page.dart';
import '../../features/storefront/presentation/pages/wishlist_page.dart';
import '../../features/support/presentation/pages/support_pages.dart';
import '../components/app_shell.dart';
import '../services/navigation_observer.dart';
import 'auth_refresh_notifier.dart';

GoRouter createAppRouter(
  AuthCubit authCubit, {
  String initialLocation = '/splash',
  AuthRefreshNotifier? refreshListenable,
}) =>
    GoRouter(
      initialLocation: initialLocation,
      observers: [NavigationObserver()],
      refreshListenable:
          refreshListenable ?? AuthRefreshNotifier(authCubit.stream),
      redirect: (_, state) => _redirect(authCubit.state, state),
      routes: _routes,
    );

String? _redirect(AuthState auth, GoRouterState state) {
  final path = state.uri.path;

  if (path.startsWith('/admin')) {
    if (!auth.isAuthenticated) return '/sign-in?redirect=$path';
    if (auth.profile?.isAdmin != true) return '/home';
    return null;
  }

  // Checkout and post-purchase/account screens require a session. Cart is
  // intentionally public — a guest must be able to review the cart they are
  // building; the auth gate moves to checkout (UI/UX review P0 funnel fix).
  const authRequired = [
    '/checkout',
    '/profile/orders',
    '/profile/addresses',
    '/wishlist',
    '/payment-method',
    '/paymob-checkout',
    '/order-success',
  ];
  if (authRequired.any(path.startsWith) && !auth.isAuthenticated) {
    return '/sign-in?redirect=$path';
  }
  return null;
}

final _routes = <RouteBase>[
  GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
  GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
  ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    GoRoute(path: '/categories', builder: (_, __) => const CategoriesPage()),
    GoRoute(
      path: '/catalog',
      builder: (_, s) => CatalogPage(
        initialQuery: s.uri.queryParameters['q'],
      ),
    ),
    GoRoute(path: '/wishlist', builder: (_, __) => const WishlistPage()),
    GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  ]),
  GoRoute(
    path: '/product/:id',
    builder: (_, s) => DetailsPage(id: s.pathParameters['id']!),
  ),
  GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
  GoRoute(
    path: '/order-success',
    builder: (_, state) => OrderSuccessPage(
      orderId: state.extra is String ? state.extra as String : '',
    ),
  ),
  GoRoute(path: '/profile/orders', builder: (_, __) => const OrdersPage()),
  GoRoute(
    path: '/profile/addresses',
    builder: (_, __) => const AddressesPage(),
  ),
  GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  GoRoute(path: '/sign-in', builder: (_, __) => const SignInPage()),
  GoRoute(path: '/sign-up', builder: (_, __) => const SignUpPage()),
  GoRoute(
    path: '/forgot-password',
    builder: (_, __) => const ForgotPasswordPage(),
  ),
  GoRoute(
    path: '/reset-password',
    builder: (_, __) => const ResetPasswordPage(),
  ),
  GoRoute(
    path: '/payment-method',
    builder: (_, s) => PaymentMethodPage(
      args: s.extra as Map<String, dynamic>? ?? {},
    ),
  ),
  GoRoute(
    path: '/paymob-checkout',
    builder: (_, s) =>
        PaymobCheckoutPage(checkoutUrl: s.extra as String? ?? ''),
  ),
  GoRoute(
    path: '/instapay-instructions',
    // No path change (router review gate): the shared PaymentCubit
    // stays load-bearing via `extra['cubit']`; `extra['orderId']` is
    // carried additively for the page's rehydration path.
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return InstapayInstructionsPage(
        cubit: extra?['cubit'] as PaymentCubit?,
        orderId: extra?['orderId'] as String?,
      );
    },
  ),
  GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardPage()),
  GoRoute(path: '/admin/orders', builder: (_, __) => const AdminOrdersPage()),
  GoRoute(
    path: '/admin/orders/:id',
    builder: (_, s) => AdminOrderDetailPage(orderId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/inventory',
    builder: (_, __) => const AdminInventoryPage(),
  ),
  GoRoute(
    path: '/admin/catalog',
    builder: (_, __) => const AdminCatalogPage(),
  ),
  // Catalog management destinations (migration-era hub tiles pointed at
  // these paths, but the routes themselves were never registered — every
  // tile dead-ended on "Page Not Found").
  GoRoute(
    path: '/admin/products',
    builder: (_, __) => const AdminProductsPage(),
  ),
  GoRoute(
    path: '/admin/products/new',
    builder: (_, __) => const AdminProductEditPage(),
  ),
  GoRoute(
    path: '/admin/products/:id',
    builder: (_, s) => AdminProductEditPage(productId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/categories',
    builder: (_, __) => const AdminCategoriesPage(),
  ),
  GoRoute(
    path: '/admin/images/:id',
    builder: (_, s) =>
        AdminImageManagerPage(productId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/variants/:id',
    builder: (_, s) =>
        AdminVariantEditorPage(productId: s.pathParameters['id']!),
  ),
  GoRoute(path: '/support', builder: (_, __) => const SupportPage()),
  GoRoute(
    path: '/privacy-policy',
    builder: (_, __) => const PrivacyPolicyPage(),
  ),
  GoRoute(path: '/terms', builder: (_, __) => const TermsOfServicePage()),
  GoRoute(
    path: '/shipping-policy',
    builder: (_, __) => const ShippingPolicyPage(),
  ),
  GoRoute(
    path: '/returns-policy',
    builder: (_, __) => const ReturnsPolicyPage(),
  ),
];
