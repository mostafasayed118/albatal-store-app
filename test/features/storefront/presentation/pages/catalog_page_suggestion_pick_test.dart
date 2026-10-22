import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recent_searches_store.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recent_searches_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/catalog_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/search_suggestions_bar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Covers the live-search branch of the catalog suggestion bar: tapping a
/// name suggestion must seed the search field, push the query into the
/// catalog and record the term as a recent search.
final class _SuggestionCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    for (final p in products) {
      if (p.id == id) return Success(p);
    }
    return const Failure(AppError('not found'));
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

final class _RecordingRecentSearches implements RecentSearchesStore {
  final List<String> _queries = [];

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

void main() {
  testWidgets('picking a live suggestion seeds the query and records it',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalog = CatalogCubit(_SuggestionCatalog());
    await catalog.load();
    final recents = RecentSearchesCubit(store: _RecordingRecentSearches());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            // `create:` so the provider owns the cubit — disposing the tree
            // cancels the cubit's 60s flash poll (no pending timer).
            BlocProvider(create: (_) => catalog),
            BlocProvider.value(value: recents),
            BlocProvider(
              create: (_) => WishlistCubit(MemoryStorefrontPersistence()),
            ),
          ],
          child: const CatalogPage(initialQuery: 'silk'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(catalog.state.filters.query, 'silk');
    expect(find.text('Suggestions'), findsOneWidget);

    // The chip lives in the suggestion bar; the grid card carries the same
    // product name, so scope the finder to the bar.
    final chip = find.descendant(
      of: find.byType(SearchSuggestionsBar),
      matching: find.text('Royal Emerald Silk'),
    );
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(catalog.state.filters.query, 'Royal Emerald Silk');
    expect(recents.state.queries.first, 'Royal Emerald Silk');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Royal Emerald Silk');
  });
}
