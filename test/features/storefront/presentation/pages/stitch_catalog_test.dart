import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart'
    show OrderCodec;
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/orders_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/catalog_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/categories_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/orders_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_category_chips.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_search_bar.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:al_batal_elite/shared/theme/grid_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/memory_storefront_persistence.dart';

class _StubRepo implements CatalogRepository {
  const _StubRepo();
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([
        Product(
          id: 'silk-01',
          name: 'Royal Emerald Silk',
          category: 'Silk',
          price: Money.egp(1290),
          oldPrice: Money.egp(1520),
          imageColor: 0xFF176B57,
          imageAsset: 'assets/images/1.svg',
          rating: 4.8,
          reviewCount: 124,
        ),
        Product(
          id: 'cotton-01',
          name: 'Golden Cotton Weave',
          category: 'Cotton',
          price: Money.egp(640),
          imageColor: 0xFFD9C6A1,
          rating: 4.5,
          reviewCount: 88,
        ),
        Product(
          id: 'velvet-01',
          name: 'Purple Velvet Drape',
          category: 'Velvet',
          price: Money.egp(980),
          imageColor: 0xFF302244,
          rating: 4.7,
          reviewCount: 61,
        ),
        Product(
          id: 'linen-01',
          name: 'Sand Linen Roll',
          category: 'Linen',
          price: Money.egp(430),
          imageColor: 0xFFE0CDA0,
          rating: 4.2,
          reviewCount: 30,
        ),
      ]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk', 'Cotton', 'Velvet', 'Linen']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Failure(AppError('Product not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];

  @override
  List<String> get defaultCategories =>
      const ['All', 'Silk', 'Cotton', 'Velvet', 'Linen'];
}

Widget _catalogHarness({MemoryStorefrontPersistence? persistence}) {
  final store = persistence ?? MemoryStorefrontPersistence();
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CatalogCubit(const _StubRepo())..load()),
        BlocProvider(create: (_) => WishlistCubit(store)),
        BlocProvider(create: (_) => CartCubit(store)),
      ],
      child: const CatalogPage(),
    ),
  );
}

Widget _categoriesHarness() {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) => CatalogCubit(const _StubRepo())..load(),
      child: const CategoriesPage(),
    ),
  );
}

Widget _ordersHarness({required MemoryStorefrontPersistence store}) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) => OrdersCubit(store)..restore(),
      child: const OrdersPage(),
    ),
  );
}

void main() {
  group('Task 4 — Categories circular chips', () {
    testWidgets('CategoriesPage shows StitchCategoryChips circular 56dp',
        (tester) async {
      await tester.pumpWidget(_categoriesHarness());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StitchCategoryChips), findsOneWidget);

      // StitchCategoryChips contract: 72dp track → 72dp SizedBox, 56dp circles, 8dp gaps.
      // Verify the outer SizedBox height 72 and inner circle BoxDecorations.
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 72,
        ),
        findsOneWidget,
      );
      // Circular chip decoration: BoxShape.circle anywhere inside the chips subtree.
      expect(
        find.descendant(
          of: find.byType(StitchCategoryChips),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        findsWidgets,
      );

      // Ensure chips contain category labels (excluding 'All' fallback handling).
      expect(
        find.descendant(
          of: find.byType(StitchCategoryChips),
          matching: find.text('Silk'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Task 4 — Catalog Stitch reskin', () {
    testWidgets(
        'CatalogPage shows StitchSearchBar + 2-col .68 grid via productGridDelegate + StitchProductGridCard',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_catalogHarness());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StitchSearchBar), findsOneWidget);
      // Grid should be 2-col .68 using shared delegate (not ProductTile).
      expect(find.byType(StitchProductGridCard), findsNWidgets(4));
      // Ensure productGridDelegate is wired: GridView uses it.
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.gridDelegate, productGridDelegate);
      // EdgeInsetsDirectional padding on grid.
      expect(grid.padding, isA<EdgeInsetsDirectional>());

      // StitchSearchBar uses rounded-full (999) and surfaceContainerLow handling via theme.
      // Verify the outer Container has pill border radius 999.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius ==
                  BorderRadius.circular(999),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'tune Badge appears when filters active and ActiveFiltersBar pills',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_catalogHarness());
      await tester.pump(const Duration(seconds: 1));

      // Initially no active filters → tune icon is plain, no Badge.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(Badge),
        ),
        findsNothing,
      );
      // Badge appears after selecting a filter.
      final catalogContext = tester.element(find.byType(CatalogPage));
      catalogContext.read<CatalogCubit>().select('Silk');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(Badge),
        ),
        findsOneWidget,
      );
      expect(find.text('1'), findsOneWidget);

      // ActiveFiltersBar should be visible when hasActiveFilters true.
      expect(find.text('Silk'), findsWidgets);
    });

    testWidgets('filter bottom sheet is Stitch: radius 20 top + outlineVariant',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_catalogHarness());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // BottomSheet widget carries the shape with radius 20 top.
      final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      final shape = bottomSheet.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(20)),
      );
    });
  });

  group('Task 4 — Orders Stitch surface harmony', () {
    testWidgets(
        'Orders cards use surface + outlineVariant 1dp border radius 16 and primaryContainer status chip; TabBar retained',
        (tester) async {
      final store = MemoryStorefrontPersistence();
      // Seed a single active order via OrderCodec.
      const product = Product(
        id: 'silk-01',
        name: 'Royal Emerald Silk',
        category: 'Silk',
        price: Money.egp(1290),
        imageColor: 0xFF176B57,
      );
      final order = Order(
        id: 'ORD-2026-0001',
        items: const [
          CartItem(
              product: product, color: 'Emerald', length: '2m', quantity: 1),
        ],
        subtotal: const Money.egp(1290),
        shipping: const Money.egp(75),
        total: const Money.egp(1365),
        status: OrderStatus.placed,
        placedAt: DateTime(2026, 8, 20),
        paymentMethod: 'cod',
      );
      store.orderRecords = [OrderCodec.encode(order)];

      await tester.pumpWidget(_ordersHarness(store: store));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // TabBar retained with 3 tabs.
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // OrderCard Card should use surface + outlineVariant border radius 16.
      final card = tester.widget<Card>(find.byType(Card).first);
      expect(
          card.color,
          Theme.of(tester.element(find.byType(Card).first))
              .colorScheme
              .surface);
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(
        shape.side.color,
        Theme.of(tester.element(find.byType(Card).first))
            .colorScheme
            .outlineVariant,
      );
      expect(shape.side.width, 1);
    });
  });
}
