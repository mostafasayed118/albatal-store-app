import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/addresses/domain/repositories/address_repository.dart';
import 'package:al_batal_elite/features/addresses/presentation/cubit/addresses_cubit.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_wholesale_price_entry.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_catalog_port.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_wholesale_prices_port.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:al_batal_elite/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:al_batal_elite/features/payments/domain/repositories/payment_service.dart';
import 'package:al_batal_elite/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/auth_session_port.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/checkout_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/coupons_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/idempotency_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recent_searches_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recently_viewed_store.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/reviews_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/wholesale_price_source.dart';
import 'package:al_batal_elite/features/storefront/domain/usecases/place_checkout_order_usecase.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recent_searches_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reorder_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/support/domain/entities/support_channel.dart';
import 'package:al_batal_elite/features/support/domain/repositories/support_repository.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/routing/app_router.dart';
import 'package:al_batal_elite/shared/routing/auth_refresh_notifier.dart';
import 'package:al_batal_elite/shared/services/analytics_service.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:al_batal_elite/shared/services/image_compressor.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:al_batal_elite/shared/services/remote_config_service.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/share_service.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:al_batal_elite/shared/services/whatsapp_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_storefront_persistence.dart';
import '../../helpers/recently_viewed_store_stub.dart';

final class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);

  @override
  Future<Result<List<String>>> fetchCategories() async => const Success([]);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const [];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success([]);
}

final class _EmptyAddresses implements AddressRepository {
  @override
  Future<Result<List<Address>>> read() async => const Success([]);

  @override
  Future<Result<void>> save(List<Address> addresses) async =>
      const Success(null);
}

final class _Settings implements SettingsRepository {
  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: AppThemeMode.system, locale: AppLocale.english));

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) async =>
      const Success(null);

  @override
  Future<Result<void>> saveLocale(AppLocale locale) async =>
      const Success(null);
}

final class _Onboarding implements OnboardingRepository {
  @override
  Future<Result<bool>> hasCompleted() async => const Success(true);

  @override
  Future<Result<void>> complete() async => const Success(null);
}

final class _Support implements SupportRepository {
  const _Support();

  @override
  List<SupportChannel> getChannels() => const [];
}

final class _Searches implements RecentSearchesStore {
  @override
  List<String> load() => const [];

  @override
  void record(String query) {}

  @override
  void clear() {}
}

final class _Wholesale implements WholesalePriceSource {
  @override
  Future<Map<String, Money>> fetchWholesalePrices(
          Iterable<String> productIds) async =>
      {};
}

final class _WholesalePort extends Fake implements AdminWholesalePricesPort {
  @override
  Future<Result<List<AdminWholesalePriceEntry>>> fetchWholesalePrices() async =>
      const Success([]);
}

final class _AdminCatalogPort extends Fake implements AdminCatalogPort {
  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async =>
      const Success([]);
}

final class _AdminRepo extends Fake implements AdminRepository {
  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) async =>
      const Success([]);
}

final class _Storage extends StorageService {
  _Storage() : super(client: null);
}

final class _Share extends Fake implements ShareService {}

final class _WhatsAppShare extends Fake implements WhatsAppShareService {}

final class _Reviews extends Fake implements ReviewsRepository {
  @override
  Future<Result<List<ProductReview>>> fetchForProduct(String productId) async =>
      const Success([]);
}

final class _Compressor extends Fake implements ImageCompressor {}

final class _CheckoutRepo extends Fake implements CheckoutRepository {}

final class _Idempotency extends Fake implements IdempotencyStore {}

final class _AuthSession extends Fake implements AuthSessionPort {
  @override
  String? currentUserEmail() => 'guest@albatal.test';
}

final class _Coupons extends Fake implements CouponsRepository {}

final class _Analytics extends Fake implements AnalyticsService {}

final class _PaymentService extends Fake implements PaymentService {}

final class _RemoteFetcher implements RemoteConfigFetcher {
  @override
  Future<Map<String, String>> fetch() async => const {};
}

final class _AuthRepo implements AuthRepository {
  @override
  Stream<Authenticated?> get authStateChanges => const Stream.empty();

  @override
  Future<Result<Authenticated?>> checkSession() async =>
      const Success(Authenticated('admin-1'));

  @override
  Future<Result<AuthOutcome>> signUp(
          {required String email,
          required String password,
          String? fullName}) async =>
      const Success(ConfirmationRequired());

  @override
  Future<Result<Authenticated>> signIn(
          {required String email, required String password}) async =>
      const Success(Authenticated('admin-1'));

  @override
  Future<Result<void>> resetPassword(String email) async => const Success(null);

  @override
  Future<Result<void>> updatePassword(String newPassword) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);
}

final class _ProfileRepo implements ProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(Profile(id: userId, isAdmin: true));

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('createAppRouter defaults the auth refresh listenable', () async {
    final auth = AuthCubit(
      authRepository: _AuthRepo(),
      profileRepository: _ProfileRepo(),
    );
    addTearDown(auth.close);

    final router = createAppRouter(auth);
    addTearDown(router.dispose);

    expect(router.configuration.routes, isNotEmpty);
  });

  testWidgets('every target route builds its page', (tester) async {
    final persistence = MemoryStorefrontPersistence();
    final catalog = _Catalog();
    final wholesale = _Wholesale();
    final checkoutRepo = _CheckoutRepo();
    final useCase = PlaceCheckoutOrderUseCase(
      checkoutRepository: checkoutRepo,
      idempotencyStore: _Idempotency(),
    );
    final paymentService = _PaymentService();
    final instapayCubit = PaymentCubit(paymentService);
    addTearDown(instapayCubit.close);

    getIt
      ..registerSingleton<CatalogRepository>(catalog)
      ..registerSingleton<ConnectivityGate>(ConnectivityGate())
      ..registerSingleton<WhatsAppShareService>(_WhatsAppShare())
      ..registerSingleton<ShareService>(_Share())
      ..registerSingleton<ReviewsRepository>(_Reviews())
      ..registerSingleton<ImageCompressor>(_Compressor())
      ..registerSingleton<RecentlyViewedStore>(MemoryRecentlyViewedStore())
      ..registerSingleton<WholesalePriceSource>(wholesale)
      ..registerSingleton<CheckoutRepository>(checkoutRepo)
      ..registerSingleton<PlaceCheckoutOrderUseCase>(useCase)
      ..registerSingleton<AuthSessionPort>(_AuthSession())
      ..registerSingleton<CouponsRepository>(_Coupons())
      ..registerSingleton<AnalyticsService>(_Analytics())
      ..registerSingleton<PaymentService>(paymentService)
      ..registerSingleton<NotificationService>(const NoOpNotificationService())
      ..registerSingleton<RemoteConfigService>(
          RemoteConfigService(fetcher: _RemoteFetcher()))
      ..registerSingleton<AdminWholesalePricesPort>(_WholesalePort())
      ..registerSingleton<AdminCatalogPort>(_AdminCatalogPort())
      ..registerSingleton<AdminRepository>(_AdminRepo())
      ..registerSingleton<StorageService>(_Storage())
      ..registerSingleton<SupportRepository>(const _Support());

    addTearDown(() async {
      await getIt.reset();
    });

    final auth = AuthCubit(
      authRepository: _AuthRepo(),
      profileRepository: _ProfileRepo(),
    );
    await auth.checkSession();

    final refreshNotifier = AuthRefreshNotifier(auth.stream);
    addTearDown(refreshNotifier.dispose);
    final router = createAppRouter(
      auth,
      initialLocation: '/privacy-policy',
      refreshListenable: refreshNotifier,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider(
            create: (_) =>
                OnboardingCubit(_Onboarding())..resolveDestination()),
        BlocProvider(create: (_) => SettingsCubit(_Settings())..load()),
        BlocProvider(
            create: (_) =>
                CatalogCubit(catalog, gate: getIt<ConnectivityGate>())..load()),
        BlocProvider(
            create: (_) => CartCubit(persistence,
                productLookup: catalog.findProductById,
                wholesalePrices: wholesale)
              ..restore()),
        BlocProvider(create: (_) => WishlistCubit(persistence)..restore()),
        BlocProvider(create: (_) => OrdersCubit(persistence)..restore()),
        BlocProvider(
            create: (_) => RecentSearchesCubit(store: _Searches())..load()),
        BlocProvider(
            create: (_) =>
                RecentlyViewedCubit(store: MemoryRecentlyViewedStore())
                  ..load()),
        BlocProvider(
          create: (_) => ReorderCubit(
            catalog: catalog,
            addToCart: (_, {color = '', length = '', quantity = 1}) {},
          ),
        ),
        BlocProvider(create: (_) => AddressesCubit(_EmptyAddresses())..load()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final visits = <String, Object?>{
      '/splash': null,
      '/wishlist': null,
      '/categories': null,
      '/catalog?q=silk': null,
      '/profile': null,
      '/product/p-1': null,
      '/checkout': null,
      '/order-success': 'ORD-1',
      '/profile/orders': null,
      '/profile/addresses': null,
      '/settings': null,
      '/sign-up': null,
      '/forgot-password': null,
      '/reset-password': null,
      '/payment-method': <String, dynamic>{
        'orderId': 'ORD-1',
        'customerEmail': 'customer@albatal.test',
        'total': const Money(10000),
      },
      '/paymob-checkout': 'https://accept.paymob.com/checkout/abc',
      '/instapay-instructions': <String, dynamic>{
        'cubit': instapayCubit,
        'orderId': 'ORD-1',
      },
      '/maintenance': null,
      '/admin/wholesale-prices': null,
      '/admin/images/p-1': null,
      '/support': null,
      '/privacy-policy': null,
      '/terms': null,
      '/shipping-policy': null,
      '/returns-policy': null,
    };

    for (final entry in visits.entries) {
      router.go(entry.key, extra: entry.value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        router.routerDelegate.currentConfiguration.matches,
        isNotEmpty,
        reason: 'route ${entry.key} did not resolve',
      );
    }
  });
}
