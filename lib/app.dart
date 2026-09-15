import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/entities/profile.dart';
import 'features/addresses/domain/repositories/address_repository.dart';
import 'features/addresses/presentation/cubit/addresses_cubit.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/admin/presentation/cubit/admin_cubit.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/repositories/order_snapshot_port.dart';
import 'features/auth/domain/repositories/profile_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/onboarding/domain/repositories/onboarding_repository.dart';
import 'features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/storefront/domain/repositories/cart_repository.dart';
import 'features/storefront/domain/repositories/catalog_repository.dart';
import 'features/storefront/domain/repositories/orders_repository.dart';
import 'features/storefront/domain/repositories/recent_searches_store.dart';
import 'features/storefront/domain/repositories/recently_viewed_store.dart';
import 'features/storefront/domain/repositories/wishlist_repository.dart';
import 'features/storefront/presentation/cubit/cart_cubit.dart';
import 'features/storefront/presentation/cubit/catalog_cubit.dart';
import 'features/storefront/presentation/cubit/orders_cubit.dart';
import 'features/storefront/presentation/cubit/recent_searches_cubit.dart';
import 'features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'features/storefront/presentation/cubit/reorder_cubit.dart';
import 'features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'generated/l10n/app_localizations.dart';
import 'shared/components/app_lock_gate.dart';
import 'shared/routing/app_router.dart';
import 'shared/routing/app_routes.dart';
import 'shared/routing/auth_refresh_notifier.dart';
import 'shared/services/biometric_service.dart';
import 'shared/services/connectivity_gate.dart';
import 'shared/services/deep_link_parser.dart';
import 'shared/services/deep_link_service.dart';
import 'shared/services/env_config.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/service_locator.dart';
import 'shared/smoke/smoke_harness.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/environment_banner.dart';

final class AlBatalApp extends StatefulWidget {
  const AlBatalApp({super.key, this.exitApp});

  /// Process-exit hook. Non-null ONLY in the debug smoke build
  /// (`lib/main_smoke.dart`), whose presence both arms and mounts the
  /// on-device smoke harness. Production entry points leave it null, so
  /// the harness never mounts there — the entry point is the gate.
  final SmokeExit? exitApp;

  @override
  State<AlBatalApp> createState() => _AlBatalAppState();
}

final class _AlBatalAppState extends State<AlBatalApp> {
  late final AuthCubit _authCubit;
  late final CartCubit _cartCubit;
  late final AuthRefreshNotifier _authRefreshNotifier;
  late final ReorderCubit _reorderCubit;
  late final RecentSearchesCubit _recentSearchesCubit;
  late final RecentlyViewedCubit _recentlyViewedCubit;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _cartCubit = CartCubit(
      getIt<CartRepository>(),
      productLookup: getIt<CatalogRepository>().findProductById,
    );
    _authCubit = AuthCubit(
      authRepository: getIt<AuthRepository>(),
      profileRepository: getIt<ProfileRepository>(),
      addressRepository: getIt<AddressRepository>(),
      orderSnapshots: getIt<OrderSnapshotPort>(),
    )..checkSession();
    _authRefreshNotifier = AuthRefreshNotifier(_authCubit.stream);
    _router = createAppRouter(
      _authCubit,
      refreshListenable: _authRefreshNotifier,
    );
    // Mirror the customer's membership tier into the cart estimate math
    // (premium = free shipping, migration 047). The authoritative perk
    // is applied server-side in create_checkout_order; this only keeps
    // the client's local estimate and order snapshot consistent.
    _authSub = _authCubit.stream.listen((auth) {
      _cartCubit.setPremiumMember(
        isPremium: auth.profile?.tier == MembershipTier.premium,
      );
    });
    // One-tap reorder (feature-batch §6): app-scoped so the orders
    // surface stays GetIt-free; cart adds flow through the live cubit.
    _reorderCubit = ReorderCubit(
      catalog: getIt<CatalogRepository>(),
      addToCart: _cartCubit.add,
    );
    // Recent catalog searches (feature-batch §7): app-scoped like the
    // reorder cubit so pages stay GetIt-free.
    _recentSearchesCubit = RecentSearchesCubit(
      store: getIt<RecentSearchesStore>(),
    )..load();
    // Recently-viewed strip (#3): app-scoped; records flow from the
    // product-details cubit, the home page only reads.
    _recentlyViewedCubit = RecentlyViewedCubit(
      store: getIt<RecentlyViewedStore>(),
    )..load();
    // Inbound deep links (feature-batch §5): parse → navigate. The
    // service swallows plugin errors on platforms without link support
    // so VM tests and web builds degrade to silence.
    _deepLinkSub = getIt<DeepLinkService>()
        .incoming()
        .listen(_handleDeepLink, onError: (Object _) {});
    // §15: the biometric app lock is owned by [AppLockGate], installed
    // around the shell in [build]. It locks on the very first frame and
    // releases only on a real authentication (audit fix — the previous
    // inline flow failed OPEN and locked only after an awaited probe).
  }

  void _handleDeepLink(Uri uri) {
    final link = parseDeepLink(
      uri,
      webBase: Uri.parse(EnvConfig.webBaseUrl),
    );
    // Route builders live on [Routes] so a path change can never leave a
    // stale literal behind (audit code-quality finding).
    if (link is ProductDeepLink) {
      _router.push(Routes.product(link.productId));
    } else if (link is CatalogDeepLink) {
      _router.push(Routes.catalogWithQuery(link.query));
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _deepLinkSub?.cancel();
    _router.dispose();
    _authRefreshNotifier.dispose();
    _reorderCubit.close();
    _recentSearchesCubit.close();
    _recentlyViewedCubit.close();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // §15: cold-start app lock. [AppLockGate] wraps the shell and renders a
    // localized, retry-able lock screen until the user authenticates;
    // [AppLockGate.child] is not inflated while locked. Null services
    // (registered-nothing tests, unsupported platform) make it a pass-through.
    return AppLockGate(
        biometrics: getIt.isRegistered<BiometricService>()
            ? getIt<BiometricService>()
            : null,
        prefs: getIt.isRegistered<AppLockPrefsStore>()
            ? getIt<AppLockPrefsStore>()
            : null,
        // Escape hatch: a user who cannot authenticate is never trapped.
        // Signing out clears the session + local PII snapshots BEFORE the
        // gate unlocks, so this is not a bypass.
        onSignOut: _authCubit.signOut,
        child: MultiBlocProvider(
            providers: [
              BlocProvider(
                  create: (_) => OnboardingCubit(
                        getIt<OnboardingRepository>(),
                      )),
              BlocProvider(
                  create: (_) => SettingsCubit(
                        getIt<SettingsRepository>(),
                        // Composition-root probe: settings tests pump the
                        // shell without the notification store registered.
                        notificationPrefs:
                            getIt.isRegistered<NotificationPrefsStore>()
                                ? getIt<NotificationPrefsStore>()
                                : null,
                        // §15: the app-lock toggle lives in Settings and flows
                        // through this cubit (the page never touches DI), so the
                        // opt-in that arms [AppLockGate] is finally reachable.
                        biometrics: getIt.isRegistered<BiometricService>()
                            ? getIt<BiometricService>()
                            : null,
                        appLockStore: getIt.isRegistered<AppLockPrefsStore>()
                            ? getIt<AppLockPrefsStore>()
                            : null,
                      )..load()),
              BlocProvider(
                  // Task #8: pass the connectivity gate so offline loads are
                  // tagged (cached restore / offline notice) instead of
                  // surfacing as errors.
                  create: (_) => CatalogCubit(getIt<CatalogRepository>(),
                      gate: getIt<ConnectivityGate>())
                    ..load()),
              BlocProvider.value(value: _cartCubit..restore()),
              BlocProvider(
                  create: (_) => WishlistCubit(
                        getIt<WishlistRepository>(),
                        // Composition-root probe (same pattern as the
                        // settings notification store above): shells without
                        // the store registered get a no-op toggle.
                        alertStore: getIt.isRegistered<BackInStockAlertStore>()
                            ? getIt<BackInStockAlertStore>()
                            : null,
                      )..restore()),
              BlocProvider(
                  create: (_) =>
                      OrdersCubit(getIt<OrdersRepository>())..restore()),
              BlocProvider.value(value: _reorderCubit),
              BlocProvider.value(value: _recentSearchesCubit),
              BlocProvider.value(value: _recentlyViewedCubit),
              BlocProvider(
                  create: (_) =>
                      AddressesCubit(getIt<AddressRepository>())..load()),
              BlocProvider.value(value: _authCubit),
              BlocProvider(create: (_) => AdminCubit(getIt<AdminRepository>())),
            ],
            child: BlocBuilder<SettingsCubit, SettingsState>(
                buildWhen: (a, b) =>
                    a.themeMode != b.themeMode || a.locale != b.locale,
                builder: (_, s) => MaterialApp.router(
                      title: 'Al Batal Elite',
                      debugShowCheckedModeBanner: false,
                      theme: AppTheme.light(),
                      darkTheme: AppTheme.dark(),
                      themeMode: s.themeMode,
                      locale: s.locale,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      routerConfig: _router,
                      builder: (context, child) => EnvironmentBanner(
                          child: widget.exitApp != null
                              ? SmokeHarness(
                                  router: _router,
                                  adminCubit: context.read<AdminCubit>(),
                                  exitApp: widget.exitApp,
                                  child: child!)
                              : child!),
                    ))));
  }
}
