import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/recently_viewed_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_category_chips.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_search_bar.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/app_fonts.dart';
import '../../../../helpers/fetch_related_stub.dart';
import '../../../../helpers/memory_storefront_persistence.dart';
import '../../../../helpers/recently_viewed_store_stub.dart';
import '../../../../helpers/stub_auth_repositories.dart';

class _StubRepo with FetchRelatedFromProducts implements CatalogRepository {
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
      const Failure(AppError('Product not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories =>
      const ['All', 'Silk', 'Cotton', 'Velvet', 'Linen'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

/// Same provider set as the home page harness (stitch_home_page_test.dart),
/// but the page subtree sits under a [MediaQuery] pinning the system text
/// scale, so every text laid out inside Home sees 1.4×.
Widget _harness() {
  final store = MemoryStorefrontPersistence();
  return MaterialApp(
    // The APP theme, not the Material default: `loadAppFonts` only takes
    // effect through a font family the theme declares (Inter/Montserrat).
    // Unthemed, every label measures ~2x its real width and this pin becomes
    // a much stricter — and misleading — test than the app itself.
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CatalogCubit(const _StubRepo())..load()),
        BlocProvider(create: (_) => WishlistCubit(store)),
        BlocProvider(create: (_) => CartCubit(store)),
        BlocProvider(
            create: (_) => AuthCubit(
                  authRepository: StubAuthRepository(),
                  profileRepository: StubProfileRepository(),
                )..checkSession()),
        // The recently-viewed strip on Home reads the app-scoped cubit —
        // same provider set as stitch_home_page_test.dart.
        BlocProvider(
            create: (_) =>
                RecentlyViewedCubit(store: MemoryRecentlyViewedStore())),
      ],
      child: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: HomePage(),
      ),
    ),
  );
}

void main() {
  // Fixed pumps only (never pumpAndSettle): the catalog cubit may run
  // periodic countdown timers for flash sales, so settle-based pumping
  // would never quiesce — same contract as stitch_home_page_test.dart.
  testWidgets(
      'Home renders search bar, category chips and grid cards without '
      'overflow at a 360dp phone viewport with 1.4 system font scale',
      (tester) async {
    // Real Inter/Montserrat: a 360dp viewport at 1.4x is the device case.
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // No layout exception anywhere in the scaled tree (the original
    // RenderFlex overflow was found on exactly this class of device).
    expect(tester.takeException(), isNull);

    // Key sections still render at scale. The popular-products grid is a
    // lazy SliverGrid: at 1.4× the content above it pushes the first
    // cards below the 740dp fold, so scroll until the grid mounts before
    // pinning it (fixed drags only — never pumpAndSettle, per the
    // countdown-timer contract above).
    expect(find.byType(StitchSearchBar), findsOneWidget);
    expect(find.byType(StitchCategoryChips), findsOneWidget);
    var scrolls = 0;
    while (
        find.byType(StitchProductGridCard).evaluate().isEmpty && scrolls < 30) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pump();
      scrolls++;
    }
    expect(find.byType(StitchProductGridCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
