import 'dart:async';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/auth_repository.dart';
import 'package:al_batal_elite/features/auth/domain/repositories/profile_repository.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/status_progress.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/routing/app_router.dart';
import 'package:al_batal_elite/shared/routing/auth_refresh_notifier.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_storefront_persistence.dart';

void main() {
  testWidgets('protected route redirects while unauthenticated',
      (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    harness.router.go('/cart');
    await _settle(tester);

    expect(harness.currentPath, '/sign-in');
    expect(harness.currentQueryParameters['redirect'], '/cart');
  });

  testWidgets('auth transition re-evaluates the guarded route', (tester) async {
    final harness = await _pumpRouter(tester, initialLocation: '/sign-in');

    // Unauthenticated: /cart is bounced to sign-in with a return path.
    harness.router.go('/cart');
    await _settle(tester);
    expect(harness.currentPath, '/sign-in');

    // Sign-in flows through the repository stream into AuthCubit. The
    // refresh listenable must observe it without an explicit navigation.
    harness.authRepository.authChanges.add(const Authenticated('user-1'));
    await _settle(tester);

    harness.router.go('/cart');
    await _settle(tester);
    expect(harness.currentPath, '/cart');

    // Sign-out: the router must leave /cart on its own (reactive redirect).
    await harness.authCubit.signOut();
    await _settle(tester);

    expect(harness.currentPath, '/sign-in');
    expect(harness.currentQueryParameters['redirect'], '/cart');
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
  });

  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: authCubit),
      BlocProvider(create: (_) => CatalogCubit(const _StubCatalogRepository())),
      BlocProvider(create: (_) => WishlistCubit(persistence)),
      BlocProvider(create: (_) => CartCubit(persistence)),
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

/// Catalog double with no products: the routing tests only need the cubit to
/// resolve without network access.
final class _StubCatalogRepository implements CatalogRepository {
  const _StubCatalogRepository();

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
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];
}
