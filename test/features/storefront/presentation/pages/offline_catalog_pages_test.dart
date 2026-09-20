import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/supabase_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/offline_catalog_view.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_shell.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/services/connectivity_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';
import '../../../../helpers/noop_share_services.dart';
import '../../../../helpers/recently_viewed_store_stub.dart';
import '../../../../helpers/stub_auth_repositories.dart';

/// Task #8 offline-catalog widget pins. The gate is seeded offline via
/// its `@visibleForTesting` constructor — no connectivity plugins run.
final offlineGate = ConnectivityGate(seedOnline: false);

class _ColdRepo with FetchRelatedFromProducts implements CatalogRepository {
  const _ColdRepo();

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Failure(AppError('Catalog unavailable'));

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('Product not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

class _WarmRepo with FetchRelatedFromProducts implements CatalogRepository {
  const _WarmRepo();

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    final product = products.where((p) => p.id == id).firstOrNull;
    if (product != null) return Success(product);
    return const Failure(AppError('Product not found'));
  }

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => categories;

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

/// Full shell: AppShell (offline banner) + HomePage, mirroring the
/// production composition root. Fixed pumps only — the catalog cubit
/// owns periodic timers.
Widget _shellHarness(CatalogRepository repo) {
  final persistence = MemoryStorefrontPersistence();
  return MultiBlocProvider(
    providers: [
      BlocProvider(
          create: (_) => CatalogCubit(repo, gate: offlineGate)..load()),
      // HomePage renders the recently-viewed strip (cross-slice union);
      // register the app-scoped store so the shell harness pumps pre-DI.
      BlocProvider(
          create: (_) =>
              RecentlyViewedCubit(store: MemoryRecentlyViewedStore())),
      BlocProvider(create: (_) => WishlistCubit(persistence)),
      BlocProvider(create: (_) => CartCubit(persistence)),
      BlocProvider(
          create: (_) => AuthCubit(
                authRepository: StubAuthRepository(),
                profileRepository: StubProfileRepository(),
              )),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(routes: [
        ShellRoute(
          builder: (_, __, child) => AppShell(gate: offlineGate, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
          ],
        ),
      ]),
    ),
  );
}

Widget _detailsHarness(CatalogRepository repo, String id) {
  final persistence = MemoryStorefrontPersistence();
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WishlistCubit(persistence)),
        BlocProvider(create: (_) => CartCubit(persistence)),
      ],
      child: DetailsPage(
        id: id,
        catalogRepository: repo,
        gate: offlineGate,
        whatsappShareService: const NoOpWhatsAppShareService(),
        shareService: const NoOpShareService(),
      ),
    ),
  );
}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  testWidgets(
      'offline + warm cache: catalog grid renders from cache, '
      'banner shows, no error view', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shellHarness(const _WarmRepo()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // The shell banner is up (gate seeded offline)…
    expect(find.byKey(const ValueKey('offlineBanner')), findsOneWidget);
    // …and the grid rendered from the repository's cache restore —
    // no error FeedbackView, no offline notice, no empty state.
    expect(find.byType(StitchProductGridCard), findsWidgets);
    expect(find.byType(OfflineCatalogView), findsNothing);
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets(
      'offline + cold cache: offline notice replaces the error '
      'FeedbackView on the home catalog', (tester) async {
    await tester.pumpWidget(_shellHarness(const _ColdRepo()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('offlineBanner')), findsOneWidget);
    expect(find.byType(OfflineCatalogView), findsOneWidget);
    // Banner copy reused (no new ARB keys): banner + notice title.
    expect(find.text('No internet connection'), findsNWidgets(2));
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets(
      'details page offline + cold cache shows the friendly '
      'notice with a working retry', (tester) async {
    await tester.pumpWidget(_detailsHarness(const _ColdRepo(), 'silk-01'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(OfflineCatalogView), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);

    // Retry re-runs the load; still offline + cold → notice persists,
    // proving the CTA is wired without crashing.
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OfflineCatalogView), findsOneWidget);
  });

  testWidgets(
      'details page offline cold start serves the persistent '
      'cache snapshot (network never answers)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = _MockSupabaseClient();
    final repo = SupabaseCatalogRepository(client: client, preferences: prefs);
    await repo.persistCacheForTest(products);
    when(() => client.from(any())).thenThrow(Exception('network offline'));

    await tester.pumpWidget(_detailsHarness(repo, 'silk-01'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // AppBar title + body header — the cached product rendered.
    expect(find.text('Royal Emerald Silk'), findsNWidgets(2));
    expect(find.byType(OfflineCatalogView), findsNothing);
    expect(find.text('Something went wrong'), findsNothing);
  });
}
