import 'package:go_router/go_router.dart';

import '../services/navigation_observer.dart';
import '../../features/admin/presentation/pages/admin_catalog_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_inventory_page.dart';
import '../../features/admin/presentation/pages/admin_order_detail_page.dart';
import '../../features/admin/presentation/pages/admin_orders_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/addresses/presentation/pages/addresses_page.dart';
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

final appRouter = GoRouter(
  initialLocation: '/home',
  observers: [NavigationObserver()],
  routes: [
  ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    GoRoute(path: '/categories', builder: (_, __) => const CategoriesPage()),
    GoRoute(
        path: '/catalog',
        builder: (_, s) => CatalogPage(
              initialQuery: s.uri.queryParameters['q'],
            )),
    GoRoute(path: '/wishlist', builder: (_, __) => const WishlistPage()),
    GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  ]),
  GoRoute(
      path: '/product/:id',
      builder: (_, s) => DetailsPage(id: s.pathParameters['id']!)),
  GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
  GoRoute(path: '/order-success', builder: (_, __) => const OrderSuccessPage()),
  GoRoute(path: '/profile/orders', builder: (_, __) => const OrdersPage()),
  GoRoute(path: '/profile/addresses', builder: (_, __) => const AddressesPage()),
  GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  // Auth routes
  GoRoute(path: '/sign-in', builder: (_, __) => const SignInPage()),
  GoRoute(path: '/sign-up', builder: (_, __) => const SignUpPage()),
  GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
  GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordPage()),
  // Payment routes
  GoRoute(path: '/payment-method', builder: (_, s) => PaymentMethodPage(args: s.extra as Map<String, dynamic>? ?? {})),
  GoRoute(path: '/paymob-checkout', builder: (_, s) => PaymobCheckoutPage(checkoutUrl: s.extra as String? ?? '')),
  // Admin routes
  GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardPage()),
  GoRoute(path: '/admin/orders', builder: (_, __) => const AdminOrdersPage()),
  GoRoute(path: '/admin/orders/:id', builder: (_, s) => AdminOrderDetailPage(orderId: s.pathParameters['id']!)),
  GoRoute(path: '/admin/inventory', builder: (_, __) => const AdminInventoryPage()),
  GoRoute(path: '/admin/catalog', builder: (_, __) => const AdminCatalogPage()),
  // Support routes
  GoRoute(path: '/support', builder: (_, __) => const SupportPage()),
  GoRoute(path: '/privacy-policy', builder: (_, __) => const PrivacyPolicyPage()),
  GoRoute(path: '/terms', builder: (_, __) => const TermsOfServicePage()),
  GoRoute(path: '/shipping-policy', builder: (_, __) => const ShippingPolicyPage()),
  GoRoute(path: '/returns-policy', builder: (_, __) => const ReturnsPolicyPage()),
]);
