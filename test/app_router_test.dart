import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_variant.dart';
import 'package:al_batal_elite/features/admin/domain/entities/low_stock_variant.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_repository.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/status_progress.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/routing/app_router.dart';
import 'package:al_batal_elite/shared/routing/auth_refresh_notifier.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:al_batal_elite/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_storefront_persistence.dart';

void main() {
  testWidgets('protected route redirects while unauthenticated',
      (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    // /cart is guest-accessible, so /wishlist stands in as the gated route
    // (same light provider needs as /cart had in this harness).
    harness.router.go('/wishlist');
    await _settle(tester);

    expect(harness.currentPath, '/sign-in');
    expect(harness.currentQueryParameters['redirect'], '/wishlist');
  });

  testWidgets('cart stays public for guests (no sign-in bounce)',
      (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    harness.router.go('/cart');
    await _settle(tester);

    // Guests may review the cart they are building — no redirect.
    expect(harness.currentPath, '/cart');
    expect(harness.currentQueryParameters.containsKey('redirect'), isFalse);
  });

  testWidgets('auth transition re-evaluates the guarded route', (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    // Unauthenticated: /wishlist is bounced to sign-in with a return path.
    harness.router.go('/wishlist');
    await _settle(tester);
    expect(harness.currentPath, '/sign-in');

    // Sign-in flows through the repository stream into AuthCubit. The
    // refresh listenable must observe it without an explicit navigation.
    harness.authRepository.authChanges.add(const Authenticated('user-1'));
    await _settle(tester);

    harness.router.go('/wishlist');
    await _settle(tester);
    expect(harness.currentPath, '/wishlist');

    // Sign-out: the router must leave /wishlist on its own (reactive redirect).
    await harness.authCubit.signOut();
    await _settle(tester);

    expect(harness.currentPath, '/sign-in');
    expect(harness.currentQueryParameters['redirect'], '/wishlist');
  });

  testWidgets('admin routes require an authenticated admin profile',
      (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    harness.router.go('/admin');
    await _settle(tester);
    expect(harness.currentPath, '/sign-in');
    expect(harness.currentQueryParameters['redirect'], '/admin');

    // Authenticated but not an admin: bounced to the storefront home.
    harness.profile.isAdmin = false;
    harness.authRepository.authChanges.add(const Authenticated('user-1'));
    await _settle(tester);

    harness.router.go('/admin');
    await _settle(tester);
    expect(harness.currentPath, '/home');
  });

  testWidgets('every admin route resolves under an admin session',
      (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    harness.profile.isAdmin = true;
    harness.authRepository.authChanges.add(const Authenticated('user-1'));
    await _settle(tester);

    // Regression: the catalog hub pushed /admin/products, /admin/categories,
    // /admin/images and /admin/variants for months without any of them being
    // registered — every tile dead-ended on "Page Not Found". This probe
    // walks each admin path and fails when the router silently redirects
    // (the GoRouter no-route behavior) instead of landing where it was told.
    const adminPaths = [
      '/admin',
      '/admin/orders',
      '/admin/orders/o-1',
      '/admin/inventory',
      '/admin/catalog',
      '/admin/products',
      '/admin/products/new',
      '/admin/products/p-1',
      '/admin/categories',
      '/admin/images/p-1',
      '/admin/variants/p-1',
    ];
    for (final path in adminPaths) {
      harness.router.go(path);
      await _settle(tester);
      expect(harness.currentPath, path,
          reason: 'admin route "$path" must resolve — a redirect away means '
              'it is unregistered or double-guarded (Page Not Found dead end)');
    }
  });

  test('auth refresh notifier stops listening after disposal', () async {
    final controller = StreamController<AuthState>.broadcast();
    final notifier = AuthRefreshNotifier(controller.stream);
    var notifications = 0;
    notifier.addListener(() => notifications++);

    // Async (default) stream controllers deliver on a later microtask.
    controller.add(const AuthState(status: AuthStatus.unauthenticated));
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);

    notifier.dispose();
    controller.add(const AuthState(status: AuthStatus.authenticated));
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);
    await controller.close();
  });

  testWidgets('order card exposes no customer status mutation', (tester) async {
    final order = Order(
      id: 'ORD-1',
      items: const [],
      subtotal: Money.zero,
      shipping: Money.zero,
      total: Money.zero,
      status: OrderStatus.placed,
      placedAt: DateTime(2026),
      paymentMethod: 'Cash on Delivery',
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => OrderCard(
          order: order,
          isCompleted: false,
          scheme: Theme.of(context).colorScheme,
        ),
      ),
    ));

    expect(find.byType(TextButton), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(find.byType(StatusProgress), findsOneWidget);
  });
}

/// Advances the router past navigation and page-transition frames.
///
/// Deliberately bounded rather than `pumpAndSettle`: the storefront owns
/// indeterminate progress indicators and tickers that never quiesce, and the
/// assertions below read [GoRouter] configuration, which settles before the
/// transition animation finishes.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Boots a [MaterialApp.router] around [createAppRouter] with the minimum
/// cubit set the shell and cart route require.
Future<_RouterHarness> _pumpRouter(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  final authRepository = _StubAuthRepository();
  final profileRepository = _StubProfileRepository();
  final adminRepo = _RouteProbeAdminRepository();
  final authCubit = AuthCubit(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
  // Resolve the session before the first frame so the sign-in CTA is not
  // stuck in the loading state (AuthStatus.initial counts as loading).
  await authCubit.checkSession();
  final refreshNotifier = AuthRefreshNotifier(authCubit.stream);
  final router = createAppRouter(
    authCubit,
    initialLocation: initialLocation,
    refreshListenable: refreshNotifier,
  );
  // Storefront cubits are created by the tree so BlocProvider owns their
  // disposal (CatalogCubit holds a periodic timer that would otherwise trip
  // the "Timer is still pending" test invariant). AuthCubit is injected
  // because the tests need a handle on it, so the harness disposes it.
  final persistence = MemoryStorefrontPersistence();

  addTearDown(() async {
    router.dispose();
    refreshNotifier.dispose();
    await authCubit.close();
    await authRepository.close();
    if (getIt.isRegistered<AdminRepository>()) {
      getIt.unregister<AdminRepository>();
    }
    if (getIt.isRegistered<StorageService>()) {
      getIt.unregister<StorageService>();
    }
  });
  if (getIt.isRegistered<AdminRepository>()) {
    getIt.unregister<AdminRepository>();
  }
  getIt.registerSingleton<AdminRepository>(adminRepo);
  // The /admin/images/:id builder resolves storage at the composition
  // root now (audit P1 constructor injection) — the route probe needs it
  // registered even though its assertions never touch images.
  if (getIt.isRegistered<StorageService>()) {
    getIt.unregister<StorageService>();
  }
  getIt.registerSingleton<StorageService>(_ProbeStorageService());

  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: authCubit),
      BlocProvider(create: (_) => CatalogCubit(const _StubCatalogRepository())),
      BlocProvider(create: (_) => WishlistCubit(persistence)),
      BlocProvider(create: (_) => CartCubit(persistence)),
      BlocProvider(create: (_) => AdminCubit(adminRepo)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  await _settle(tester);

  return _RouterHarness(
    router: router,
    authCubit: authCubit,
    authRepository: authRepository,
    profile: profileRepository,
  );
}

final class _RouterHarness {
  const _RouterHarness({
    required this.router,
    required this.authCubit,
    required this.authRepository,
    required this.profile,
  });

  final GoRouter router;
  final AuthCubit authCubit;
  final _StubAuthRepository authRepository;
  final _StubProfileRepository profile;

  String get currentPath => router.routerDelegate.currentConfiguration.uri.path;

  Map<String, String> get currentQueryParameters =>
      router.routerDelegate.currentConfiguration.uri.queryParameters;
}

final class _StubAuthRepository implements AuthRepository {
  final authChanges = StreamController<Authenticated?>.broadcast();

  @override
  Stream<Authenticated?> get authStateChanges => authChanges.stream;

  @override
  Future<Result<Authenticated?>> checkSession() async => const Success(null);

  @override
  Future<Result<AuthOutcome>> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async =>
      const Success(ConfirmationRequired());

  @override
  Future<Result<Authenticated>> signIn({
    required String email,
    required String password,
  }) async =>
      const Success(Authenticated('user-1'));

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

  Future<void> close() => authChanges.close();
}

final class _StubProfileRepository implements ProfileRepository {
  bool isAdmin = false;

  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      Success(Profile(id: userId, isAdmin: isAdmin));

  @override
  Future<Result<void>> upsertProfile(Profile profile) async =>
      const Success(null);
}

/// Storage double for the composition-root resolution in the route
/// probe: nothing here is asserted, it only has to construct.
final class _ProbeStorageService extends StorageService {
  _ProbeStorageService() : super(client: null);

  @override
  String getProductImageUrl(String storagePath) => 'https://probe/$storagePath';
}

/// Catalog double with no products: the routing tests only need the cubit to
/// resolve without network access.
final class _StubCatalogRepository implements CatalogRepository {  const _StubCatalogRepository();

  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);

  @override
  Future<Result<List<String>>> fetchCategories() async => const Success([]);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('Product not found.'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const [];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

/// Empty admin repository for the route probe: the admin pages built by
/// the probed routes only need their repositories to resolve — they show
/// their own empty/error states, which the assertions never inspect.
final class _RouteProbeAdminRepository implements AdminRepository {
  @override
  Future<Result<void>> setMembershipTier(String profileId, String tier) async =>
      const Success(null);

  @override
  Future<bool> isCurrentUserAdmin() async => true;

  @override
  Future<Result<List<AdminOrder>>> getAllOrders(
          {AdminOrderStatus? status, int limit = 50}) async =>
      const Success([]);

  @override
  Future<Result<AdminOrder?>> getOrderDetails(String orderId) async =>
      const Success(null);

  @override
  Future<Result<void>> updateOrderStatus(
          String orderId, AdminOrderStatus status,
          {String? trackingNumber}) async =>
      const Success(null);

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts(
          {int threshold = 5}) async =>
      const Success([]);

  @override
  Future<Result<void>> updateStock(String variantId, int newStock) async =>
      const Success(null);

  @override
  Future<Result<String>> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    required String categoryId,
    required double basePrice,
    required bool isActive,
  }) async =>
      const Success('probe');

  @override
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    double? priceOverride,
  }) async =>
      const Success('probe');

  @override
  Future<Result<void>> adminSetProductImages(
          String productId, List<String> storagePaths) async =>
      const Success(null);

  @override
  Future<Result<List<AdminVariant>>> getVariants(String productId) async =>
      const Success([]);

  @override
  Future<Result<List<String>>> getProductImagePaths(String productId) async =>
      const Success([]);

  @override
  Future<Result<List<AdminProduct>>> getAllProducts() async =>
      const Success([]);

  @override
  Future<Result<List<AdminCategory>>> getAllCategories() async =>
      const Success([]);
}
