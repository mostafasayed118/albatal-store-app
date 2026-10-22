import 'package:al_batal_elite/core/entities/address.dart';
import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/product_review.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/address_tile.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/catalog_sort_bar.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/fit_recommender_sheet.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/home/popular_header.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/name_and_price.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/reviews/review_tile_body.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/stock_badge.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/variant_selector.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/wishlist_tile.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/wishlist_toggle_icon.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/zoom_gallery.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/extensions/build_context_x.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../helpers/memory_storefront_persistence.dart';

const _basic = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(500),
  imageColor: 0xFF176B57,
  colors: ['Emerald', 'Gold'],
  sizes: ['1m', '2m'],
  stock: {'Emerald-1m': 4, 'Emerald-2m': 7},
);

const _metered = Product(
  id: 'meter-01',
  name: 'Metered Silk',
  category: 'Silk',
  price: Money.egp(400),
  imageColor: 0xFF176B57,
  sellByLength: true,
  minCutMeters: 1,
  colors: ['Gold', 'Amber'],
  stock: {'Gold-1m': 5},
);

final class _Catalog implements CatalogRepository {
  _Catalog([this.items = const [_basic]]);

  final List<Product> items;

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(items));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk']);

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    for (final p in items) {
      if (p.id == id) return Success(p);
    }
    return const Failure(AppError('not found'));
  }

  @override
  Future<Result<List<Product>>> fetchRelated(
    String category, {
    String? excludeId,
    int limit = 8,
  }) async =>
      Success(items
          .where((p) => p.category == category && p.id != excludeId)
          .take(limit)
          .toList());

  @override
  Product? findProductById(String id) =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  List<String> get defaultCategories => const ['All', 'Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

Widget _plain(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Widget _l10n(Widget Function(BuildContext) builder) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: builder)),
    );

Widget _detailsHarness(Product product) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) =>
            ProductDetailsCubit(_Catalog([product]))..loadProduct(product.id),
        child: Scaffold(
          body: BlocBuilder<ProductDetailsCubit, DetailsState>(
            builder: (context, state) => state.status == DetailsStatus.ready
                ? SingleChildScrollView(
                    child: VariantSelector(
                      product: state.product!,
                      state: state,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

Future<void> _pumpDetails(WidgetTester tester, Product product) async {
  await tester.pumpWidget(_detailsHarness(product));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('NameAndPrice', () {
    testWidgets('a wholesale list price labels the negotiated row',
        (tester) async {
      final wholesale = _basic.withWholesalePrice(const Money.egp(420));
      await tester.pumpWidget(_plain(NameAndPrice(product: wholesale)));

      expect(find.text('Wholesale price'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });

    testWidgets('a catalog price has no wholesale row', (tester) async {
      await tester.pumpWidget(_plain(const NameAndPrice(product: _basic)));

      expect(find.text('Wholesale price'), findsNothing);
    });
  });

  group('StockBadge', () {
    testWidgets('a low stock level renders the remaining count',
        (tester) async {
      await tester.pumpWidget(_l10n((context) => StockBadge(
            stock: 2,
            l: context.l10n,
          )));

      expect(find.text('Only 2 left'), findsOneWidget);
    });
  });

  group('AddressTile', () {
    const address = Address(
      id: 'a1',
      recipient: 'Sara Ahmed',
      line: '45 Nile Corniche',
      city: 'Cairo',
      country: 'Egypt',
    );

    testWidgets('an errored, unselected tile shows the error border and radio',
        (tester) async {
      await tester.pumpWidget(_l10n((context) => AddressTile(
            address: address,
            isSelected: false,
            hasError: true,
            l: context.l10n,
            scheme: Theme.of(context).colorScheme,
            onTap: () {},
          )));

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      final card = tester.widget<Card>(find.byType(Card));
      final border = (card.shape! as RoundedRectangleBorder).side;
      expect(border.color,
          Theme.of(tester.element(find.byType(AddressTile))).colorScheme.error);
    });
  });

  group('ReviewTileBody', () {
    testWidgets('renders the bounded photo when the review carries one',
        (tester) async {
      final review = ProductReview(
        id: 'r1',
        productId: 'silk-01',
        authorName: 'Nour',
        rating: 4,
        text: 'Lovely drape',
        createdAt: DateTime.utc(2026, 9, 1),
        photoUrl: 'https://example.com/review.jpg',
      );

      await tester.pumpWidget(_plain(ReviewTileBody(review: review)));
      await tester.pump();

      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.text('Lovely drape'), findsOneWidget);
    });
  });

  group('WishlistTile', () {
    testWidgets('move-to-cart adds the item, un-wishlists it, and confirms',
        (tester) async {
      final persistence = MemoryStorefrontPersistence()
        ..wishlistIds = {'silk-01'};
      final wishlist = WishlistCubit(persistence);
      await wishlist.restore();
      final cart = CartCubit(persistence);
      addTearDown(wishlist.close);
      addTearDown(cart.close);

      final router = GoRouter(
        initialLocation: '/wishlist',
        routes: [
          GoRoute(
            path: '/wishlist',
            builder: (_, __) =>
                const Scaffold(body: WishlistTile(product: _basic)),
          ),
          GoRoute(
            path: '/product/:id',
            builder: (_, __) => const Scaffold(body: Text('Product stub')),
          ),
        ],
      );

      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wishlist),
          BlocProvider.value(value: cart),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));

      await tester.tap(find.text('Move to Cart'));
      await tester.pump();

      expect(cart.state.items.single.product.id, 'silk-01');
      expect(wishlist.state.ids, isNot(contains('silk-01')));
      expect(find.text('Moved to cart'), findsOneWidget);
    });

    testWidgets('tapping the tile opens the product details route',
        (tester) async {
      final persistence = MemoryStorefrontPersistence();
      final wishlist = WishlistCubit(persistence);
      final cart = CartCubit(persistence);
      addTearDown(wishlist.close);
      addTearDown(cart.close);

      final router = GoRouter(
        initialLocation: '/wishlist',
        routes: [
          GoRoute(
            path: '/wishlist',
            builder: (_, __) =>
                const Scaffold(body: WishlistTile(product: _basic)),
          ),
          GoRoute(
            path: '/product/:id',
            builder: (_, __) => const Scaffold(body: Text('Product stub')),
          ),
        ],
      );

      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wishlist),
          BlocProvider.value(value: cart),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));

      await tester.tap(find.text('Royal Emerald Silk'));
      await tester.pumpAndSettle();

      expect(find.text('Product stub'), findsOneWidget);
    });
  });

  group('WishlistToggleIcon', () {
    testWidgets('toggles the saved state and swaps the tooltip',
        (tester) async {
      final persistence = MemoryStorefrontPersistence();
      final wishlist = WishlistCubit(persistence);
      addTearDown(wishlist.close);

      await tester.pumpWidget(BlocProvider.value(
        value: wishlist,
        child: _plain(const WishlistToggleIcon(productId: 'silk-01')),
      ));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byTooltip('Add to wishlist'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(wishlist.state.ids, contains('silk-01'));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byTooltip('Removed from wishlist'), findsOneWidget);
    });
  });

  group('CatalogSortBar', () {
    testWidgets('selecting a sort option drives the catalog cubit',
        (tester) async {
      final catalog = CatalogCubit(_Catalog());
      addTearDown(catalog.close);

      await tester.pumpWidget(BlocProvider.value(
        value: catalog,
        child: _l10n((context) => CatalogSortBar(state: catalog.state)),
      ));

      await tester.tap(find.byType(Chip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest').last);
      await tester.pumpAndSettle();

      expect(catalog.state.filters.sort, CatalogSort.newest);
    });
  });

  group('HomePopularHeader', () {
    testWidgets('the popup reports the picked sort to its owner',
        (tester) async {
      CatalogSort? picked;
      await tester.pumpWidget(_l10n((context) => HomePopularHeader(
            title: 'Popular',
            sort: CatalogSort.featured,
            onSortSelected: (s) => picked = s,
          )));

      await tester.tap(find.byType(Chip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest').last);
      await tester.pumpAndSettle();

      expect(picked, CatalogSort.newest);
    });
  });

  group('VariantSelector missing branches', () {
    testWidgets('a non-numeric cut length falls back to the minimum cut',
        (tester) async {
      await _pumpDetails(tester, _metered);
      final cubit = tester
          .element(find.byType(VariantSelector))
          .read<ProductDetailsCubit>();

      cubit.length('');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();

      expect(cubit.state.length, '1.0');
    });

    testWidgets('the metered fit finder opens the recommender sheet',
        (tester) async {
      await _pumpDetails(tester, _metered);

      await tester.tap(find.text('Find my fit'));
      await tester.pumpAndSettle();

      expect(find.byType(FitRecommenderSheet), findsOneWidget);
    });

    testWidgets('the fixed-size fit finder opens the recommender sheet',
        (tester) async {
      await _pumpDetails(tester, _basic);

      await tester.tap(find.text('Find my fit'));
      await tester.pumpAndSettle();

      expect(find.byType(FitRecommenderSheet), findsOneWidget);
    });

    testWidgets('the quantity stepper writes through to the cubit',
        (tester) async {
      await _pumpDetails(tester, _basic);
      final cubit = tester
          .element(find.byType(VariantSelector))
          .read<ProductDetailsCubit>();

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      expect(cubit.state.quantity, 2);
    });
  });

  group('ZoomGallery', () {
    test('resolves providers by source shape', () {
      expect(ZoomGallery.imageProviderFor(''), isNull);
      expect(ZoomGallery.imageProviderFor('http://example.com/a.jpg'), isNull);
      expect(
        ZoomGallery.imageProviderFor('https://example.com/a.jpg'),
        isA<CachedNetworkImageProvider>(),
      );
      expect(
        ZoomGallery.imageProviderFor('assets/images/1.svg'),
        isA<ResizeImage>(),
      );
    });

    testWidgets('builds pages, falls back for unsupported sources, and pages',
        (tester) async {
      await tester.pumpWidget(_l10n((context) => const ZoomGallery(
            images: [
              'assets/images/1.svg',
              'https://example.com/a.jpg',
              'http://example.com/b.jpg',
            ],
            initialIndex: 0,
            imageColor: 0xFF176B57,
          )));
      // First frame: the gallery is loading its first page.
      await tester.pump();
      expect(find.byIcon(Icons.texture), findsWidgets);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.drag(find.byType(PhotoViewGallery), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });
  });
}
