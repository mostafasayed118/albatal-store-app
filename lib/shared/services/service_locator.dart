import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/addresses/data/local_address_repository.dart';
import '../../features/addresses/domain/repositories/address_repository.dart';
import '../../features/admin/data/supabase_admin_repository.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/data/supabase_auth_session_port.dart';
import '../../features/auth/data/supabase_profile_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/order_snapshot_port.dart';
import '../../features/auth/domain/repositories/profile_repository.dart';
import '../../features/onboarding/data/local_onboarding_repository.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/payments/data/paymob_payment_service.dart';
import '../../features/payments/domain/repositories/payment_service.dart';
import '../../features/settings/data/local_settings_repository.dart';
import '../../features/settings/data/notification_prefs_store.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/storefront/data/back_in_stock_alert_store.dart';
import '../../features/storefront/data/checkout_service.dart';
import '../../features/storefront/data/local_cart_repository.dart';
import '../../features/storefront/data/local_wishlist_repository.dart';
import '../../features/storefront/data/recent_searches_store.dart';
import '../../features/storefront/data/recently_viewed_store.dart';
import '../../features/storefront/data/storefront_persistence.dart';
import '../../features/storefront/data/supabase_catalog_repository.dart';
import '../../features/storefront/data/supabase_coupons_repository.dart';
import '../../features/storefront/data/supabase_orders_repository.dart';
import '../../features/storefront/data/supabase_reviews_repository.dart';
import '../../features/storefront/domain/repositories/auth_session_port.dart';
import '../../features/storefront/domain/repositories/cart_repository.dart';
import '../../features/storefront/domain/repositories/catalog_repository.dart';
import '../../features/storefront/domain/repositories/checkout_repository.dart';
import '../../features/storefront/domain/repositories/coupons_repository.dart';
import '../../features/storefront/domain/repositories/idempotency_store.dart';
import '../../features/storefront/domain/repositories/orders_repository.dart';
import '../../features/storefront/domain/repositories/recent_searches_store.dart';
import '../../features/storefront/domain/repositories/recently_viewed_store.dart';
import '../../features/storefront/domain/repositories/reviews_repository.dart';
import '../../features/storefront/domain/repositories/wishlist_repository.dart';
import '../../features/storefront/domain/usecases/place_checkout_order_usecase.dart';
import '../../features/support/data/local_support_repository.dart';
import '../../features/support/domain/repositories/support_repository.dart';
import '../../shared/services/crash_reporting_service.dart';
import '../../shared/services/env_config.dart';
import '../../shared/services/sentry_crash_reporting_service.dart';
import 'analytics_service.dart';
import 'biometric_service.dart';
import 'connectivity_gate.dart';
import 'deep_link_service.dart';
import 'image_compressor.dart';
import 'notification_service.dart';
import 'oauth_service.dart';
import 'push_service.dart';
import 'remote_config_service.dart';
import 'secure_store.dart';
import 'share_service.dart';
import 'storage_service.dart';
import 'whatsapp_share_service.dart';

final getIt = GetIt.instance;

/// Configure the dependency-injection container.
///
/// All repositories and services are registered as lazy singletons so
/// they're created once on first access and shared thereafter. Cubits
/// are NOT registered here — they're created per-route via
/// [BlocProvider] in the widget tree (per INSTRUCTIONS.md §B.3 and
/// the GetIt convention of keeping stateful objects out of the DI
/// container unless they're truly app-scoped).
Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<SharedPreferences>(preferences)
    // Encrypted at-rest store for PII (address book, order snapshots)
    // and the Supabase session — one shared instance so the auth wipe
    // and the repos observe the same on-device store.
    ..registerLazySingleton<SecureStore>(() => FlutterSecureStore())
    ..registerLazySingleton<SettingsRepository>(
        () => LocalSettingsRepository(getIt<SharedPreferences>()))
    ..registerLazySingleton<OnboardingRepository>(
        () => LocalOnboardingRepository(getIt<SharedPreferences>()))
    ..registerLazySingleton<LocalAddressRepository>(() =>
        LocalAddressRepository(getIt<SharedPreferences>(),
            secureStore: getIt<SecureStore>()))
    // One shared instance behind both registrations: the auth wipe and
    // the address book must observe the same on-device store.
    ..registerLazySingleton<AddressRepository>(
        () => getIt<LocalAddressRepository>())
    ..registerLazySingleton<AdminRepository>(() => SupabaseAdminRepository())
    ..registerLazySingleton<AuthRepository>(() => SupabaseAuthRepository())
    ..registerLazySingleton<ProfileRepository>(
        () => SupabaseProfileRepository())
    ..registerLazySingleton<PaymentService>(() => PaymobPaymentService())
    ..registerLazySingleton<CheckoutRepository>(() => CheckoutService())
    ..registerLazySingleton<SupportRepository>(
        () => const LocalSupportRepository())
    ..registerLazySingleton<LocalStorefrontPersistence>(() =>
        LocalStorefrontPersistence(getIt<SharedPreferences>(),
            secureStore: getIt<SecureStore>()))
    // Auth snapshot wipe (audit S9) via the domain port — the cubit
    // never sees the concrete persistence class.
    ..registerLazySingleton<OrderSnapshotPort>(
        () => getIt<LocalStorefrontPersistence>())
    // Checkout idempotency persistence + orchestration: the cubit and
    // page resolve these ports, never SharedPreferences directly.
    ..registerLazySingleton<IdempotencyStore>(
        () => getIt<LocalStorefrontPersistence>())
    ..registerLazySingleton<PlaceCheckoutOrderUseCase>(
        () => PlaceCheckoutOrderUseCase(
              checkoutRepository: getIt<CheckoutRepository>(),
              idempotencyStore: getIt<IdempotencyStore>(),
            ))
    // Customer email for the payment handoff without Supabase imports
    // in the presentation layer.
    ..registerLazySingleton<AuthSessionPort>(() => SupabaseAuthSessionPort())
    ..registerLazySingleton<CartRepository>(
        () => LocalCartRepository(getIt<LocalStorefrontPersistence>()))
    ..registerLazySingleton<WishlistRepository>(
        () => LocalWishlistRepository(getIt<LocalStorefrontPersistence>()))
    // Server-backed orders in ALL builds: checkout creates orders
    // server-side via the `create_checkout_order` RPC (CheckoutService
    // is registered unconditionally above), so the orders list must
    // read from the server too. A local fallback here made debug
    // builds show a permanently empty orders screen (live-found
    // 2026-09-03).
    ..registerLazySingleton<OrdersRepository>(() => SupabaseOrdersRepository())
    ..registerLazySingleton<CatalogRepository>(() =>
        SupabaseCatalogRepository(preferences: getIt<SharedPreferences>()))
    ..registerLazySingleton<StorageService>(() => StorageService())
    // Two-layer offline signal (B1+B2): interface flap + reachability truth.
    // App-scoped and stateless — widgets observe via their own cubits.
    ..registerLazySingleton<ConnectivityGate>(() => ConnectivityGate())
    // Crash reporting: Use Sentry when DSN is configured, NoOp otherwise.
    ..registerLazySingleton<CrashReportingService>(() {
      if (EnvConfig.sentryDsn.isNotEmpty) {
        return SentryCrashReportingService();
      }
      return const NoOpCrashReportingService();
    })
    // Upload-image compression (feature-batch §4). Fail-open by design:
    // an unavailable plugin returns the original bytes.
    ..registerLazySingleton<ImageCompressor>(
        () => const FlutterImageCompressor())
    // §5/§14: the generic share-sheet sink — §5 product share and §14
    // admin CSV export both route through it.
    ..registerLazySingleton<ShareService>(() => const SharePlusShareService())
    // #13: WhatsApp-first product share (wa.me universal link).
    ..registerLazySingleton<ExternalLinkLauncher>(
        () => const UrlLauncherExternalLinkLauncher())
    ..registerLazySingleton<WhatsAppShareService>(
        () => WaMeWhatsAppShareService(getIt<ExternalLinkLauncher>()))
    // §5: inbound deep links (initial + warm events).
    ..registerLazySingleton<DeepLinkService>(() => AppLinksDeepLinkService())
    // §7: persisted recent catalog searches.
    ..registerLazySingleton<RecentSearchesStore>(
        () => PrefsRecentSearchesStore(getIt<SharedPreferences>()))
    // #3: persisted recently-viewed product snapshots (home strip).
    ..registerLazySingleton<RecentlyViewedStore>(
        () => PrefsRecentlyViewedStore(getIt<SharedPreferences>()))
    // §8/§9: coupon validation + customer reviews.
    ..registerLazySingleton<CouponsRepository>(
        () => SupabaseCouponsRepository())
    ..registerLazySingleton<ReviewsRepository>(
        () => SupabaseReviewsRepository())
    // §11: first-party funnel analytics (fail-silent).
    ..registerLazySingleton<AnalyticsService>(() => AnalyticsService())
    // §12: local order-status notifications + push scaffold (both
    // fail-silent; push stays a no-op without ONESIGNAL_APP_ID).
    ..registerLazySingleton<NotificationPrefsStore>(
        () => PrefsNotificationStore(getIt<SharedPreferences>()))
    ..registerLazySingleton<NotificationService>(
        () => LocalNotificationService(prefs: getIt<NotificationPrefsStore>()))
    // Task #5: per-product back-in-stock alert opt-ins (client-side).
    ..registerLazySingleton<BackInStockAlertStore>(
        () => PrefsBackInStockAlertStore(getIt<SharedPreferences>()))
    ..registerLazySingleton<PushService>(() => const OneSignalPushService())
    // §15: OAuth sign-in + biometric app lock (both fail-soft).
    ..registerLazySingleton<OAuthService>(() => SupabaseOAuthService())
    ..registerLazySingleton<BiometricService>(() => LocalBiometricService())
    ..registerLazySingleton<AppLockPrefsStore>(
        () => PrefsAppLockStore(getIt<SharedPreferences>()))
    // §13: remote config (defaults + TTL cache; advisory only).
    ..registerLazySingleton<RemoteConfigService>(() => RemoteConfigService());
}
