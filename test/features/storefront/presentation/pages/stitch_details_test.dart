import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/data/local_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import '../../../../helpers/stub_auth_repositories.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/cart_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/cart_item_tile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_flash_sale_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
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
          imageColor: 0xFF176B57,
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
      const Success(['All', 'Silk', 'Cotton']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      Failure(AppError('Product not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => const [];

  @override
  List<String> get defaultCategories => const ['All', 'Silk', 'Cotton'];
}

const _stubProduct = Product(
  id: 'velvet-01',
  name: 'Purple Velvet Drape',
  category: 'Velvet',
  price: Money.egp(980),
  imageColor: 0xFF302244,
);

MaterialApp _app({
  required Widget Function(BuildContext) builder,
  MemoryStorefrontPersistence? persistence,
}) {
  final store = persistence ?? MemoryStorefrontPersistence();
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WishlistCubit(store)),
        BlocProvider(create: (_) => CartCubit(store)),
      ],
      child: Builder(builder: builder),
    ),
  );
}

void main() {
  group('Stitch details reskin', () {
    Widget detailsHarness(String productId) {
      final repo = LocalCatalogRepository();
      return _app(
        builder: (_) => DetailsPage(id: productId, catalogRepository: repo),
      );
    }

    testWidgets(
        'gallery is clipped to the 16dp card radius and the CTA sits '
        'in a 72dp gold bottom bar', (tester) async {
      await tester.pumpWidget(detailsHarness('silk-01'));
      await tester.pump(const Duration(milliseconds: 100));

      // Gallery wrapped in ClipRRect(cardRadius 16).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ClipRRect &&
              w.borderRadius == const BorderRadius.all(Radius.circular(16)),
        ),
        findsOneWidget,
      );

      // EGY-suffixed pricing stays visible.
      expect(find.textContaining('EGY'), findsWidgets);

      // Single FilledButton CTA, gold (#904D00 secondary token).
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style?.backgroundColor?.resolve(const {}),
        const Color(0xFF904D00),
      );

      // CTA bar: Container height 72 wrapping the button.
      expect(
        find.ancestor(
          of: find.byType(FilledButton),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxHeight == 72,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the gold CTA adds the selected variant to the cart',
        (tester) async {
      await tester.pumpWidget(detailsHarness('silk-01'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      final context = tester.element(find.byType(DetailsPage));
      final cart = context.read<CartCubit>();
      expect(cart.state.items, hasLength(1));
      // ProductDetailsCubit preselects sizes.first / colors.first.
      expect(cart.state.items.first.key, 'silk-01-Emerald-1m');
      expect(cart.state.items.first.quantity, 1);
    });
  });

  group('Task 2 deferred wiring (spec section 5)', () {
    Widget homeHarness() => _app(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => CatalogCubit(const _StubRepo())..load(),
              ),
              BlocProvider(
                create: (_) => AuthCubit(
                  authRepository: StubAuthRepository(),
                  profileRepository: StubProfileRepository(),
                )..checkSession(),
              ),
            ],
            child: const HomePage(),
          ),
        );

    testWidgets('grid card heart toggles the wishlist cubit', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(seconds: 1));

      Finder firstCardHeart() => find.descendant(
            of: find.byType(StitchProductGridCard).first,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Icon &&
                  (w.icon == Icons.favorite || w.icon == Icons.favorite_border),
            ),
          );
      await tester.ensureVisible(firstCardHeart());
      await tester.tap(firstCardHeart());
      await tester.pump();

      final context = tester.element(find.byType(HomePage));
      expect(context.read<WishlistCubit>().state.ids, contains('silk-01'));

      // Toggling again removes it.
      await tester.tap(firstCardHeart());
      await tester.pump();
      expect(
          context.read<WishlistCubit>().state.ids, isNot(contains('silk-01')));
    });

    testWidgets('flash sale add FAB adds the product to the cart',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(seconds: 1));

      final addFab = find.descendant(
        of: find.byType(StitchFlashSaleCard),
        matching: find.byIcon(Icons.add),
      );
      await tester.ensureVisible(addFab);
      await tester.tap(addFab);
      await tester.pump();

      final context = tester.element(find.byType(HomePage));
      final items = context.read<CartCubit>().state.items;
      expect(items, hasLength(1));
      expect(items.first.product.id, 'silk-01');
      expect(items.first.quantity, 1);
    });
  });

  group('Cart page Stitch alignment', () {
    testWidgets('item tiles carry an outlineVariant border', (tester) async {
      final store = MemoryStorefrontPersistence();
      final cart = CartCubit(store);
      cart.add(_stubProduct);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cart),
            BlocProvider(create: (_) => WishlistCubit(store)),
          ],
          child: const CartPage(),
        ),
      ));
      await tester.pump();

      final tileContext = tester.element(find.byType(CartItemTile));
      final expectedBorder = Theme.of(tileContext).colorScheme.outlineVariant;
      final tileCardShape = tester
          .widget<Card>(
            find
                .descendant(
                  of: find.byType(CartItemTile),
                  matching: find.byType(Card),
                )
                .first,
          )
          .shape as RoundedRectangleBorder;
      expect(tileCardShape.side.color, expectedBorder);
    });
  });
}
