import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/categories_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';

/// Catalog stub whose product fetch fails until [fail] is cleared.
final class _ToggleCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  bool fail = true;

  @override
  Future<Result<List<Product>>> fetchProducts() async => fail
      ? const Failure(AppError('catalog offline'))
      : Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk', 'Cotton']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('single-row fetch unavailable'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All', 'Silk', 'Cotton'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

Widget _app(GoRouter router) => MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

void main() {
  testWidgets('a failed catalog load shows the error state with a retry',
      (tester) async {
    final catalog = CatalogCubit(_ToggleCatalog());
    addTearDown(catalog.close);
    await catalog.load();
    expect(catalog.state.status, CatalogStatus.error);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: catalog,
          child: const CategoriesPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('tapping a category card selects it and routes to the catalog',
      (tester) async {
    final catalog = CatalogCubit(_ToggleCatalog()..fail = false);
    await catalog.load();

    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        GoRoute(
          path: '/categories',
          builder: (_, __) => BlocProvider(
            // `create:` so the provider owns the cubit — disposing the route
            // cancels the cubit's 60s flash poll (no pending timer).
            create: (_) => catalog,
            child: const CategoriesPage(),
          ),
        ),
        GoRoute(
          path: '/catalog',
          builder: (_, __) => const Scaffold(body: Text('Catalog stub')),
        ),
      ],
    );

    await tester.pumpWidget(_app(router));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(
      find.descendant(
        of: find.byType(GridView),
        matching: find.text('Silk'),
      ),
    );
    await tester.pumpAndSettle();

    expect(catalog.state.filters.category, 'Silk');
    expect(find.text('Catalog stub'), findsOneWidget);
  });
}
