import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_category_chips.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_search_bar.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/memory_storefront_persistence.dart';

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
          imageAsset: 'assets/images/1.png',
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
      ]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk', 'Cotton', 'Velvet', 'Linen']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories =>
      const ['All', 'Silk', 'Cotton', 'Velvet', 'Linen'];
}

Widget _harness({
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
  MemoryStorefrontPersistence? persistence,
}) {
  final store = persistence ?? MemoryStorefrontPersistence();
  final t = theme ?? AppTheme.light();
  return MaterialApp(
    theme: t,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Directionality(
      textDirection: direction,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CatalogCubit(const _StubRepo())..load()),
          BlocProvider(create: (_) => WishlistCubit(store)),
          BlocProvider(create: (_) => CartCubit(store)),
        ],
        child: const HomePage(),
      ),
    ),
  );
}

void main() {
  group('Stitch RTL golden smoke — lightweight LTR/RTL + light/dark', () {
    testWidgets('HomePage pumps LTR', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(direction: TextDirection.ltr));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StitchCategoryChips), findsOneWidget);
      expect(find.byType(StitchSearchBar), findsOneWidget);
      // Verify Directionality wrapping HomePage is LTR.
      final dir = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.byType(HomePage),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(dir.textDirection, TextDirection.ltr);
    });

    testWidgets('HomePage pumps RTL (Directionality TextDirection.rtl)',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(direction: TextDirection.rtl));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StitchCategoryChips), findsOneWidget);
      expect(find.byType(StitchSearchBar), findsOneWidget);
      final dir = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.byType(HomePage),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(dir.textDirection, TextDirection.rtl);
    });

    testWidgets('HomePage pumps dark (AppTheme.dark)', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(theme: AppTheme.dark()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StitchCategoryChips), findsOneWidget);
      expect(find.byType(StitchSearchBar), findsOneWidget);
      final ctx = tester.element(find.byType(HomePage));
      expect(Theme.of(ctx).brightness, Brightness.dark);
      expect(Theme.of(ctx).scaffoldBackgroundColor.toARGB32(),
          AppTheme.dark().scaffoldBackgroundColor.toARGB32());
    });

    testWidgets('HomePage pumps light', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(theme: AppTheme.light()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StitchCategoryChips), findsOneWidget);
      expect(find.byType(StitchSearchBar), findsOneWidget);
      final ctx = tester.element(find.byType(HomePage));
      expect(Theme.of(ctx).brightness, Brightness.light);
      expect(Theme.of(ctx).scaffoldBackgroundColor.toARGB32(),
          AppTheme.light().scaffoldBackgroundColor.toARGB32());
    });
  });
}
