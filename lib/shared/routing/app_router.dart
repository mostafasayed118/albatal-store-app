import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/addresses/presentation/pages/addresses_page.dart';
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
import '../components/app_shell.dart';

final appRouter = GoRouter(initialLocation: '/home', routes: [
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
  GoRoute(
      path: '/order-success',
      builder: (_, s) => const OrderSuccessPage()),
  GoRoute(path: '/profile/orders', builder: (_, __) => const OrdersPage()),
  GoRoute(
      path: '/profile/addresses',
      builder: (_, __) => const AddressesPage()),
  GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  // Auth routes
  GoRoute(path: '/sign-in', builder: (_, __) => const SignInPage()),
  GoRoute(path: '/sign-up', builder: (_, __) => const SignUpPage()),
  GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordPage()),
  GoRoute(
      path: '/reset-password',
      builder: (_, __) => const ResetPasswordPage()),
]);
