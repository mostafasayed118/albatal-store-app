import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/filter_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_colors.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fetch_related_stub.dart';

/// Flash source the test can mutate between polls.
class _FlashCatalog with FetchRelatedFromProducts implements CatalogRepository {
  List<FlashSale> sales = const [
    FlashSale(productId: 'p1', discountPct: 20),
  ];

  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('Product not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async => Success(sales);
}

Widget _filterHarness(CatalogState state) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: FilterSheet(state: state, onApply: (_, __, ___, ____) {})),
    );

void main() {
  group('CatalogCubit — flash poll deep-equal skip (review-batch-med)', () {
    blocTest<CatalogCubit, CatalogState>(
      'emits once for two identical polls',
      build: () => CatalogCubit(_FlashCatalog()),
      act: (cubit) async {
        await cubit.loadFlashSales();
        await cubit.loadFlashSales();
      },
      expect: () => [
        CatalogState(
          flashSales: [const FlashSale(productId: 'p1', discountPct: 20)],
        ),
      ],
    );

    test('changed sales emit a second state', () async {
      final repo = _FlashCatalog();
      final cubit = CatalogCubit(repo);
      await cubit.loadFlashSales();
      expect(cubit.state.flashSales, hasLength(1));
      repo.sales = const [
        FlashSale(productId: 'p1', discountPct: 20),
        FlashSale(productId: 'p2', discountPct: 30),
      ];
      await cubit.loadFlashSales();
      expect(cubit.state.flashSales, hasLength(2));
      await cubit.close();
    });
  });

  group('FilterSheet — degenerate price range (review-batch-med)', () {
    testWidgets('single-price catalog shows a fixed price, no slider',
        (tester) async {
      const single = Product(
        id: 'only',
        name: 'Only Fabric',
        category: 'Silk',
        price: Money.egp(1290),
        imageColor: 0xFF000000,
      );
      final state = CatalogState(
        status: CatalogStatus.ready,
        allProducts: const [single],
        categories: const ['All', 'Silk'],
      );
      await tester.pumpWidget(_filterHarness(state));
      await tester.pumpAndSettle();

      // The price row sits below the fold of the 0.6-height sheet —
      // ListView builds lazily, so scroll it into view first.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.byType(RangeSlider), findsNothing);
      // Fixed-price text + the collapsed start/end labels all read the
      // single catalog price.
      expect(find.text(const Money.egp(1290).format()), findsNWidgets(3));
    });
  });

  group('AppTheme — dark containers (review-batch-med)', () {
    test('dark scheme carries the new container roles', () {
      final dark = AppTheme.dark().colorScheme;
      expect(dark.primaryContainer, AppColors.darkPrimaryContainer);
      expect(dark.secondaryContainer, AppColors.darkSecondaryContainer);
      expect(dark.tertiary, AppColors.darkTertiary);
      expect(dark.surfaceContainerLow, AppColors.darkSurfaceContainerLow);
      expect(dark.surfaceContainer, AppColors.darkSurfaceContainer);
      expect(dark.surfaceContainerHigh, AppColors.darkSurfaceContainerHigh);
    });

    test('light scheme is unchanged', () {
      final light = AppTheme.light().colorScheme;
      expect(light.primary, AppColors.primary);
      expect(light.primaryContainer, AppColors.primaryContainer);
      expect(light.secondary, AppColors.secondary);
      expect(light.secondaryContainer, AppColors.secondaryContainer);
      expect(light.tertiary, AppColors.tertiary);
      expect(light.surface, AppColors.surface);
      expect(light.surfaceContainerLow, AppColors.surfaceContainerLow);
      expect(light.surfaceContainer, AppColors.surfaceContainer);
      expect(light.surfaceContainerHigh, AppColors.surfaceContainerHigh);
    });
  });
}
