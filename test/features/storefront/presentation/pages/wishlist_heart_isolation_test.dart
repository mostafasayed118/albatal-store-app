import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/catalog_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';
import '../../../../helpers/stub_auth_repositories.dart';

class _StubRepo
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success(_products);
  @override
  Future<Result<List<String>>> fetchCategories() async => const Success([
        'Silk',
        'Cotton',
      ]);
  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));
  @override
  Product? findProductById(String id) => null;
  @override
  List<String> get defaultCategories => const ['All'];
  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

const _products = [
  Product(
    id: 'p1',
    name: 'Royal Emerald Silk',
    category: 'Silk',
    price: Money.egp(1290),
    imageColor: 0xFF176B57,
    rating: 4.8,
    reviewCount: 124,
  ),
  Product(
    id: 'p2',
    name: 'Golden Cotton Weave',
    category: 'Cotton',
    price: Money.egp(640),
    imageColor: 0xFFD9C6A1,
    rating: 4.5,
    reviewCount: 88,
  ),
  Product(
    id: 'p3',
    name: 'Ivory Linen Drape',
    category: 'Linen',
    price: Money.egp(890),
    imageColor: 0xFFEDE3CF,
    rating: 4.2,
    reviewCount: 51,
  ),
];

Widget _homeHarness(MemoryStorefrontPersistence store) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CatalogCubit(_StubRepo())..load()),
          BlocProvider(create: (_) => WishlistCubit(store)),
          BlocProvider(create: (_) => CartCubit(store)),
          BlocProvider(
            create: (_) => AuthCubit(
              authRepository: StubAuthRepository(),
              profileRepository: StubProfileRepository(),
            ),
          ),
        ],
        child: const HomePage(),
      ),
    );

void main() {
  testWidgets('home grid hearts are per-item BlocSelectors (audit P3)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    await tester.pumpWidget(_homeHarness(store));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    final cards = find.byType(StitchProductGridCard);
    expect(cards, findsNWidgets(3));

    // Structural pin: every grid card wraps its heart in a per-item
    // BlocSelector<WishlistCubit, WishlistState, bool>, so a wishlist
    // toggle rebuilds one heart — never the ~100-card grid.
    final selectors =
        tester.widgetList<BlocSelector<WishlistCubit, WishlistState, bool>>(
      find.byType(
        BlocSelector<WishlistCubit, WishlistState, bool>,
      ),
    );
    expect(selectors.length, greaterThanOrEqualTo(3));

    // Functional: toggle rebuilds the heart glyph for that card only.
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
  });

  testWidgets('catalog grid hearts toggle in place (audit P3)', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CatalogCubit(_StubRepo())..load()),
          BlocProvider(create: (_) => WishlistCubit(store)),
        ],
        child: const CatalogPage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(StitchProductGridCard), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
  });
}
