import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/catalog_empty_state.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/home/flash_sale_card.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/home/recent_queries.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_hero_carousel.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';
import '../../../../helpers/recently_viewed_store_stub.dart';
import '../../../../helpers/stub_auth_repositories.dart';

final class _HomeCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  _HomeCatalog({this.flashSale});

  final FlashSale? flashSale;

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Success(products.firstWhere((p) => p.id == id));

  @override
  Product? findProductById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => categories;

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      Success([if (flashSale != null) flashSale!]);
}

GoRouter _router() => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/product/:id',
          builder: (_, s) =>
              Scaffold(body: Text('Product stub ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/categories',
          builder: (_, __) => const Scaffold(body: Text('Categories stub')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const Scaffold(body: Text('Settings stub')),
        ),
      ],
    );

Widget _app(GoRouter router, CatalogCubit catalog) {
  final persistence = MemoryStorefrontPersistence();
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => catalog),
      BlocProvider(create: (_) => WishlistCubit(persistence)),
      BlocProvider(create: (_) => CartCubit(persistence)),
      BlocProvider(
        create: (_) => AuthCubit(
          authRepository: StubAuthRepository(),
          profileRepository: StubProfileRepository(),
        )..checkSession(),
      ),
      BlocProvider(
        create: (_) => RecentlyViewedCubit(store: MemoryRecentlyViewedStore()),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('recent queries render under the search bar and can be deleted',
      (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(_HomeCatalog());
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    catalog.updateQuery('silk');
    await tester.pump(const Duration(milliseconds: 350));
    catalog.updateQuery('');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(HomeRecentQueries), findsOneWidget);
    expect(find.text('silk'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(HomeRecentQueries),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();

    expect(catalog.state.recentQueries, isEmpty);
    expect(find.byType(HomeRecentQueries), findsNothing);
  });

  testWidgets('the empty state clears the query and filters', (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(_HomeCatalog());
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    catalog.updateQuery('no-such-fabric');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(CatalogEmptyState), findsOneWidget);
    expect(catalog.state.visible, isEmpty);

    await tester.tap(find.text('View all fabrics'));
    await tester.pump();

    expect(catalog.state.filters.query, isEmpty);
    expect(find.byType(CatalogEmptyState), findsNothing);
    expect(find.byType(StitchProductGridCard), findsWidgets);
  });

  testWidgets('settings action pushes the settings route', (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(_HomeCatalog());
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings stub'), findsOneWidget);
  });

  testWidgets('the promo slide CTA goes to categories', (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(_HomeCatalog());
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Shop Now'));
    await tester.pumpAndSettle();

    expect(find.text('Categories stub'), findsOneWidget);
  });

  testWidgets('a product grid card opens the product route', (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(_HomeCatalog());
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(StitchProductGridCard).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Product stub'), findsOneWidget);
  });

  testWidgets('a featured hero slide opens its product', (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(_HomeCatalog());
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('stitch_hero_dot_1')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(StitchHeroCarousel),
        matching: find.text('Midnight Velvet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Product stub'), findsOneWidget);
  });

  testWidgets('a flash sale for an unknown product falls back to the first',
      (tester) async {
    _useTallViewport(tester);
    final catalog = CatalogCubit(
      _HomeCatalog(
        flashSale: FlashSale(
          productId: 'missing-product',
          discountPct: 25,
          endsAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
    );
    await catalog.load();

    await tester.pumpWidget(_app(_router(), catalog));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HomeFlashSaleCard), findsOneWidget);
    expect(catalog.state.flashSales.single.productId, 'missing-product');
  });
}
