import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/active_filters_bar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/fetch_related_stub.dart';

class _Repo with FetchRelatedFromProducts implements CatalogRepository {
  const _Repo();

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      Success(List.of(categories));

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => categories;

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

CatalogCubit _fullyFilteredCubit() {
  return CatalogCubit(const _Repo())
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
}

Widget _harness(CatalogCubit cubit, {VoidCallback? onClearAll}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => cubit,
        child: Builder(
          builder: (context) => Scaffold(
            body: ActiveFiltersBar(
              state: context.read<CatalogCubit>().state,
              onClearAll: onClearAll ?? () {},
            ),
          ),
        ),
      ),
    );

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(3000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders one chip per active filter plus clear all',
      (tester) async {
    _wide(tester);
    await tester.pumpWidget(_harness(_fullyFilteredCubit()));

    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('100 EGP – 2,000 EGP'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Wide'), findsOneWidget);
    expect(find.text('cotton'), findsOneWidget);
    expect(find.text('In stock only'), findsOneWidget);
    expect(find.text('Sold by the meter only'), findsOneWidget);
    expect(find.text('Minimum rating 4.5+'), findsOneWidget);
    expect(find.text('Remnants only'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
  });

  testWidgets('deleting the category chip resets it to All', (tester) async {
    _wide(tester);
    final cubit = _fullyFilteredCubit();
    await tester.pumpWidget(_harness(cubit));

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(Chip, 'Silk'),
        matching: find.byIcon(Icons.cancel),
      ),
    );

    expect(cubit.state.filters.category, 'All');
  });

  testWidgets('deleting the color chip clears the color filter',
      (tester) async {
    _wide(tester);
    final cubit = _fullyFilteredCubit();
    await tester.pumpWidget(_harness(cubit));

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(Chip, 'Gold'),
        matching: find.byIcon(Icons.cancel),
      ),
    );

    expect(cubit.state.filters.colorFilter, isEmpty);
  });

  testWidgets('every chip deletes its own facet', (tester) async {
    _wide(tester);
    final cubit = _fullyFilteredCubit();
    await tester.pumpWidget(_harness(cubit));

    Future<void> deleteChip(String label) async {
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Chip, label),
          matching: find.byIcon(Icons.cancel),
        ),
      );
      await tester.pump();
    }

    await deleteChip('Silk');
    await deleteChip('Gold');
    await deleteChip('100 EGP – 2,000 EGP');
    await deleteChip('Medium');
    await deleteChip('Wide');
    await deleteChip('cotton');
    await deleteChip('In stock only');
    await deleteChip('Sold by the meter only');
    await deleteChip('Minimum rating 4.5+');
    await deleteChip('Remnants only');

    expect(cubit.state.filters, const CatalogFilters());
  });

  testWidgets('clear all invokes the page callback', (tester) async {
    _wide(tester);
    var cleared = false;
    await tester.pumpWidget(
      _harness(_fullyFilteredCubit(), onClearAll: () => cleared = true),
    );

    await tester.tap(find.text('Clear all'));

    expect(cleared, isTrue);
  });

  testWidgets('an unfiltered state renders no chips', (tester) async {
    await tester.pumpWidget(_harness(CatalogCubit(const _Repo())));

    expect(find.byType(Chip), findsNothing);
    expect(find.text('Clear all'), findsNothing);
  });
}
