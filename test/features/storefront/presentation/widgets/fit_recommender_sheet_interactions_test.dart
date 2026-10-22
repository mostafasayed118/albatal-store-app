import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/fit_recommender_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';

const _narrowMetered = Product(
  id: 'metered',
  name: 'Narrow Metered Silk',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF176B57,
  widthCm: 110,
  sellByLength: true,
  minCutMeters: 1.0,
);

final class _OneProduct
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Success([_narrowMetered]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Success(_narrowMetered);

  @override
  Product? findProductById(String id) =>
      id == _narrowMetered.id ? _narrowMetered : null;

  @override
  List<String> get defaultCategories => const ['All', 'Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

Widget _harness(Product product, ProductDetailsCubit cubit) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(body: FitRecommenderSheet(product: product)),
      ),
    );

void main() {
  testWidgets('the height stepper moves in 5 cm steps and clamps',
      (tester) async {
    final cubit = ProductDetailsCubit(_OneProduct());
    addTearDown(cubit.close);
    await cubit.loadProduct(_narrowMetered.id);

    await tester.pumpWidget(_harness(_narrowMetered, cubit));
    await tester.pumpAndSettle();

    expect(find.text('175 cm'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    expect(find.text('170 cm'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    expect(find.text('180 cm'), findsOneWidget);
  });

  testWidgets('a narrow roll shows the extra-length note', (tester) async {
    final cubit = ProductDetailsCubit(_OneProduct());
    addTearDown(cubit.close);
    await cubit.loadProduct(_narrowMetered.id);

    await tester.pumpWidget(_harness(_narrowMetered, cubit));
    await tester.pumpAndSettle();

    expect(find.text('Narrow roll — extra length included'), findsOneWidget);
    expect(find.textContaining('4.0 m'), findsWidgets);
  });

  testWidgets('Apply writes the metered cut into the details cubit',
      (tester) async {
    final cubit = ProductDetailsCubit(_OneProduct());
    addTearDown(cubit.close);
    await cubit.loadProduct(_narrowMetered.id);

    await tester.pumpWidget(_harness(_narrowMetered, cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use 4.0 m'));
    await tester.pumpAndSettle();

    expect(cubit.state.length, '4.0');
  });

  test('a repository without the product still loads an error state', () async {
    final cubit = ProductDetailsCubit(_FailingCatalog());
    addTearDown(cubit.close);
    await cubit.loadProduct('missing');

    expect(cubit.state.status, DetailsStatus.error);
  });
}

final class _FailingCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      const Failure(AppError('offline'));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('offline'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}
