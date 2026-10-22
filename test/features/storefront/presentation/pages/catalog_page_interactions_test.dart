import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recent_searches_store.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recent_searches_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/catalog_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/active_filters_bar.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/catalog_empty_state.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/filter_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

class _Repo with FetchRelatedFromProducts implements CatalogRepository {
  const _Repo();

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    for (final product in products) {
      if (product.id == id) return Success(product);
    }
    return const Failure(AppError('not found'));
  }

  @override
  Product? findProductById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  List<String> get defaultCategories => categories;

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

class _MemoryRecentSearches implements RecentSearchesStore {
  _MemoryRecentSearches([List<String> seed = const []])
      : _queries = List.of(seed);

  final List<String> _queries;

  @override
  List<String> load() => List.of(_queries);

  @override
  void record(String query) {
    _queries
      ..remove(query)
      ..insert(0, query);
  }

  @override
  void clear() => _queries.clear();
}

Widget _harness({
  required CatalogCubit catalog,
  required RecentSearchesCubit recents,
  String? initialQuery,
}) =>
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => catalog),
          BlocProvider(create: (_) => recents),
          BlocProvider(
            create: (_) => WishlistCubit(MemoryStorefrontPersistence()),
          ),
        ],
        child: CatalogPage(initialQuery: initialQuery),
      ),
    );

Future<void> _pumpPage(
  WidgetTester tester, {
  required CatalogCubit catalog,
  required RecentSearchesCubit recents,
  String? initialQuery,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _harness(catalog: catalog, recents: recents, initialQuery: initialQuery),
  );
  await tester.pump();
}

Future<CatalogCubit> _loadedCatalog() async {
  final catalog = CatalogCubit(const _Repo());
  await catalog.load();
  return catalog;
}

void main() {
  testWidgets('initialQuery seeds the debounced query and suggestions',
      (tester) async {
    final catalog = await _loadedCatalog();
    await _pumpPage(
      tester,
      catalog: catalog,
      recents: RecentSearchesCubit(store: _MemoryRecentSearches()),
      initialQuery: 'silk',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(catalog.state.filters.query, 'silk');
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Royal Emerald Silk'), findsWidgets);
  });

  testWidgets('recent searches render as pickable chips', (tester) async {
    final catalog = await _loadedCatalog();
    final recents = RecentSearchesCubit(
      store: _MemoryRecentSearches(const ['gold']),
    )..load();
    await _pumpPage(tester, catalog: catalog, recents: recents);

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('gold'), findsOneWidget);

    await tester.tap(find.text('gold'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(catalog.state.filters.query, 'gold');
    expect(recents.state.queries.first, 'gold');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'gold');
  });

  testWidgets('clearing recent searches hides the suggestion bar',
      (tester) async {
    final catalog = await _loadedCatalog();
    final recents = RecentSearchesCubit(
      store: _MemoryRecentSearches(const ['gold']),
    )..load();
    await _pumpPage(tester, catalog: catalog, recents: recents);

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(recents.state.queries, isEmpty);
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('submitting the search records a recent query', (tester) async {
    final catalog = await _loadedCatalog();
    final recents = RecentSearchesCubit(store: _MemoryRecentSearches());
    await _pumpPage(tester, catalog: catalog, recents: recents);

    await tester.enterText(find.byType(TextField), 'velvet');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(recents.state.queries.first, 'velvet');

    await tester.pump(const Duration(milliseconds: 400));
    expect(catalog.state.filters.query, 'velvet');
  });

  testWidgets('clear all resets filters and empties the search field',
      (tester) async {
    final catalog = await _loadedCatalog();
    catalog.select('Silk');
    await _pumpPage(
      tester,
      catalog: catalog,
      recents: RecentSearchesCubit(store: _MemoryRecentSearches()),
    );

    expect(find.byType(ActiveFiltersBar), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'silk');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ActiveFiltersBar), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pump();

    expect(catalog.state.filters, const CatalogFilters());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('empty state CTA restores the full grid', (tester) async {
    final catalog = await _loadedCatalog();
    await _pumpPage(
      tester,
      catalog: catalog,
      recents: RecentSearchesCubit(store: _MemoryRecentSearches()),
    );

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CatalogEmptyState), findsOneWidget);

    await tester.tap(find.text('View all fabrics'));
    await tester.pump();

    expect(catalog.state.filters.query, isEmpty);
    expect(find.byType(CatalogEmptyState), findsNothing);
    expect(find.byType(StitchProductGridCard), findsWidgets);

    await tester.tap(find.byType(StitchProductGridCard).first);
    await tester.pump();
    expect(find.byType(CatalogPage), findsOneWidget);
  });

  testWidgets('the filter badge counts every active facet', (tester) async {
    final catalog = await _loadedCatalog();
    catalog
      ..select('Silk')
      ..setColorFilter('Gold')
      ..setPriceRange(const Money.egp(100), const Money.egp(2000))
      ..setFabricWeight(FabricWeight.medium)
      ..setFabricWidth(FabricWidth.wide)
      ..setFabricKeyword('cotton')
      ..setInStockOnly(true)
      ..setSellByLengthOnly(true)
      ..setMinRating(4.5)
      ..setRemnantsOnly(true);

    await _pumpPage(
      tester,
      catalog: catalog,
      recents: RecentSearchesCubit(store: _MemoryRecentSearches()),
    );

    final badge = tester.widget<Badge>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Badge),
      ),
    );
    expect((badge.label! as Text).data, '9');
  });

  testWidgets('applying the filter sheet commits every facet', (tester) async {
    final catalog = await _loadedCatalog();
    await _pumpPage(
      tester,
      catalog: catalog,
      recents: RecentSearchesCubit(store: _MemoryRecentSearches()),
    );

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(FilterSheet), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(FilterSheet),
        matching: find.text('Cotton'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(catalog.state.filters.category, 'Cotton');
    expect(catalog.state.filters.priceMin, catalog.state.catalogPriceMin);
  });

  testWidgets('tapping a product card pushes the product route',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalog = await _loadedCatalog();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => catalog),
              BlocProvider(
                create: (_) =>
                    RecentSearchesCubit(store: _MemoryRecentSearches()),
              ),
              BlocProvider(
                create: (_) => WishlistCubit(MemoryStorefrontPersistence()),
              ),
            ],
            child: const CatalogPage(),
          ),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(StitchProductGridCard).first);
    await tester.pumpAndSettle();

    expect(find.text('detail silk-01'), findsOneWidget);
  });
}
