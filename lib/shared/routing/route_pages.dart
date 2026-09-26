import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../features/addresses/presentation/pages/addresses_page.dart';
import '../../features/admin/domain/repositories/admin_coupons_port.dart';
import '../../features/admin/domain/repositories/admin_customers_port.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/domain/repositories/admin_reviews_port.dart';
import '../../features/admin/domain/repositories/admin_sales_port.dart';
import '../../features/admin/presentation/pages/admin_catalog_page.dart';
import '../../features/admin/presentation/pages/admin_categories_page.dart';
import '../../features/admin/presentation/pages/admin_coupons_page.dart';
import '../../features/admin/presentation/pages/admin_customers_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_image_manager_page.dart';
import '../../features/admin/presentation/pages/admin_inventory_page.dart';
import '../../features/admin/presentation/pages/admin_order_detail_page.dart';
import '../../features/admin/presentation/pages/admin_orders_page.dart';
import '../../features/admin/presentation/pages/admin_product_edit_page.dart';
import '../../features/admin/presentation/pages/admin_products_page.dart';
import '../../features/admin/presentation/pages/admin_reviews_page.dart';
import '../../features/admin/presentation/pages/admin_sales_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_variant_editor_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/payments/domain/repositories/payment_service.dart';
import '../../features/payments/presentation/cubit/payment_cubit.dart';
import '../../features/payments/presentation/pages/instapay_instructions_page.dart';
import '../../features/payments/presentation/pages/payment_method_page.dart';
import '../../features/payments/presentation/pages/paymob_checkout_page.dart';
import '../../features/settings/presentation/pages/maintenance_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/storefront/domain/repositories/auth_session_port.dart';
import '../../features/storefront/domain/repositories/catalog_repository.dart';
import '../../features/storefront/domain/repositories/checkout_repository.dart';
import '../../features/storefront/domain/repositories/coupons_repository.dart';
import '../../features/storefront/domain/repositories/recently_viewed_store.dart';
import '../../features/storefront/domain/repositories/reviews_repository.dart';
import '../../features/storefront/domain/usecases/place_checkout_order_usecase.dart';
import '../../features/storefront/presentation/pages/cart_page.dart';
import '../../features/storefront/presentation/pages/catalog_page.dart';
import '../../features/storefront/presentation/pages/categories_page.dart';
import '../../features/storefront/presentation/pages/checkout_page.dart';
import '../../features/storefront/presentation/pages/details_page.dart';
import '../../features/storefront/presentation/pages/home_page.dart';
import '../../features/storefront/presentation/pages/order_success_page.dart';
import '../../features/storefront/presentation/pages/orders_page.dart';
import '../../features/storefront/presentation/pages/wishlist_page.dart';
import '../../features/support/domain/repositories/support_repository.dart';
import '../../features/support/presentation/pages/support_pages.dart';
import '../components/app_shell.dart';
import '../services/analytics_service.dart';
import '../services/connectivity_gate.dart';
import '../services/image_compressor.dart';
import '../services/notification_service.dart';
import '../services/oauth_service.dart';
import '../services/remote_config_service.dart';
import '../services/service_locator.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_share_service.dart';
import '../settings_account_adapter.dart';

/// Page construction for the route table (audit 2026-09-21, P2): the
/// composition-root logic — service location, `getIt.isRegistered`
/// pre-DI test affordances, and argument parsing — lives HERE, so
/// `app_router.dart` is a scannable path table. One static factory per
/// route; bodies are verbatim moves from the old inline builders.
abstract final class RoutePages {
  static Widget splash() => SplashPage(
        // §13 remote config is resolved at the composition root; the
        // fail-soft probe keeps tests (which pump pre-DI) advisory-only.
        remoteConfig: getIt.isRegistered<RemoteConfigService>()
            ? getIt<RemoteConfigService>()
            : null,
      );

  static Widget onboarding() => const OnboardingPage();

  static Widget appShell(Widget child) =>
      AppShell(gate: getIt<ConnectivityGate>(), child: child);

  static Widget home() => const HomePage();

  static Widget categories() => const CategoriesPage();

  static Widget catalog(GoRouterState s) => CatalogPage(
        initialQuery: s.uri.queryParameters['q'],
      );

  static Widget wishlist() => WishlistPage(
        // §5 restock notifications resolved at the composition root;
        // the NoOp keeps pre-DI widget tests silent.
        notificationService: getIt.isRegistered<NotificationService>()
            ? getIt<NotificationService>()
            : const NoOpNotificationService(),
      );

  static Widget cart() => const CartPage();

  static Widget profile() => const ProfilePage();

  static Widget productDetail(GoRouterState s) => DetailsPage(
        id: s.pathParameters['id']!,
        catalogRepository: getIt<CatalogRepository>(),
        gate: getIt<ConnectivityGate>(),
        whatsappShareService: getIt<WhatsAppShareService>(),
        shareService: getIt<ShareService>(),
        reviewsRepository: getIt.isRegistered<ReviewsRepository>()
            ? getIt<ReviewsRepository>()
            : null,
        imageCompressor: getIt.isRegistered<ImageCompressor>()
            ? getIt<ImageCompressor>()
            : null,
        recentlyViewed: getIt.isRegistered<RecentlyViewedStore>()
            ? getIt<RecentlyViewedStore>()
            : null,
      );

  static Widget checkout() => CheckoutPage(
        checkoutRepository: getIt<CheckoutRepository>(),
        placeOrder: getIt.isRegistered<PlaceCheckoutOrderUseCase>()
            ? getIt<PlaceCheckoutOrderUseCase>()
            : null,
        authSession: getIt<AuthSessionPort>(),
        couponsRepository: getIt<CouponsRepository>(),
        analytics: getIt<AnalyticsService>(),
      );

  static Widget orderSuccess(GoRouterState s) => OrderSuccessPage(
        orderId: s.extra is String ? s.extra as String : '',
        // §12 local order confirmation resolved at the composition root.
        notificationService: getIt.isRegistered<NotificationService>()
            ? getIt<NotificationService>()
            : const NoOpNotificationService(),
      );

  static Widget orders() => const OrdersPage();

  static Widget addresses() => const AddressesPage();

  static Widget settings(BuildContext context) =>
      SettingsPage(accountDeletion: SettingsAccountAdapter(context));

  static Widget signIn() => SignInPage(
        // Composition-root probe (audit 2026-09-13): tests pump the
        // shell without the OAuth bean registered.
        oauthService:
            getIt.isRegistered<OAuthService>() ? getIt<OAuthService>() : null,
      );

  static Widget signUp() => const SignUpPage();

  static Widget forgotPassword() => const ForgotPasswordPage();

  static Widget resetPassword() => const ResetPasswordPage();

  static Widget paymentMethod(GoRouterState s) => PaymentMethodPage(
        args: s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : {},
        // Composition root resolves the service (audit 2026-09-13:
        // payments getIt x2 closed — verifier must-fix #1).
        paymentService: getIt<PaymentService>(),
      );

  static Widget paymobCheckout(GoRouterState s) => PaymobCheckoutPage(
      checkoutUrl: s.extra is String ? s.extra as String : '');

  /// No path change (router review gate): the shared PaymentCubit
  /// stays load-bearing via `extra['cubit']`; `extra['orderId']` is
  /// carried additively for the page's rehydration path.
  static Widget instapayInstructions(GoRouterState s) {
    final extra = s.extra;
    final map = extra is Map<String, dynamic> ? extra : null;
    final cubit = map?['cubit'];
    final orderId = map?['orderId'];
    final compressor =
        getIt.isRegistered<ImageCompressor>() ? getIt<ImageCompressor>() : null;
    return InstapayInstructionsPage(
      imageCompressor: compressor,
      cubit: cubit is PaymentCubit ? cubit : null,
      orderId: orderId is String ? orderId : null,
      // Rehydration path resolves at the composition root.
      paymentService: getIt<PaymentService>(),
    );
  }

  static Widget adminDashboard() => const AdminDashboardPage();

  /// Composition root (audit P1): the only place that resolves
  /// dependencies; the page's own `getIt` lookup is now only a
  /// test-only fallback.
  static Widget adminOrders() =>
      AdminOrdersPage(shareService: getIt<ShareService>());

  /// Composition root (audit P1): the only place that resolves
  /// dependencies; the page's own `getIt` lookup is now only a
  /// test-only fallback.
  ///
  /// Narrow port (audit Top-5 #5 ISP): the reviews page only moderates,
  /// so it receives [AdminReviewsPort], not the full facade.
  static Widget adminReviews() =>
      AdminReviewsPage(repository: getIt<AdminReviewsPort>());

  static Widget maintenance() => const MaintenancePage();

  static Widget adminCustomers() =>
      AdminCustomersPage(repository: getIt<AdminCustomersPort>());

  /// Composition root (audit P1): the only place that resolves
  /// dependencies, like every other admin destination.
  static Widget adminCoupons() =>
      AdminCouponsPage(repository: getIt<AdminCouponsPort>());

  static Widget adminOrderDetail(GoRouterState s) =>
      AdminOrderDetailPage(orderId: s.pathParameters['id']!);

  static Widget adminInventory() => const AdminInventoryPage();

  static Widget adminCatalog() =>
      AdminCatalogPage(repository: getIt<AdminRepository>());

  /// Read-only sales dashboard (#12); repository resolved at the
  /// composition root like every other admin destination.
  static Widget adminSales() =>
      AdminSalesDashboardPage(repository: getIt<AdminSalesPort>());

  static Widget adminProducts() =>
      AdminProductsPage(repository: getIt<AdminRepository>());

  static Widget adminProductNew() =>
      AdminProductEditPage(repository: getIt<AdminRepository>());

  static Widget adminProductEdit(GoRouterState s) => AdminProductEditPage(
        productId: s.pathParameters['id']!,
        repository: getIt<AdminRepository>(),
      );

  static Widget adminCategories() =>
      AdminCategoriesPage(repository: getIt<AdminRepository>());

  static Widget adminImages(GoRouterState s) => AdminImageManagerPage(
        productId: s.pathParameters['id']!,
        // Composition root (audit P1): the only place that resolves
        // dependencies; pages receive them via constructors.
        repository: getIt<AdminRepository>(),
        storage: getIt<StorageService>(),
        // §4 compression pass on the real upload path (audit 2026-09-13).
        imageCompressor: getIt.isRegistered<ImageCompressor>()
            ? getIt<ImageCompressor>()
            : null,
      );

  static Widget adminVariantEdit(GoRouterState s) => AdminVariantEditorPage(
        productId: s.pathParameters['id']!,
        repository: getIt<AdminRepository>(),
      );

  static Widget support() =>
      SupportPage(supportRepository: getIt<SupportRepository>());

  static Widget privacyPolicy() => const PrivacyPolicyPage();

  static Widget terms() => const TermsOfServicePage();

  static Widget shippingPolicy() => const ShippingPolicyPage();

  static Widget returnsPolicy() => const ReturnsPolicyPage();
}
