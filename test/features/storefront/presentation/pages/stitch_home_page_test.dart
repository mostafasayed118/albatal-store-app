import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/features/auth/domain/entities/auth_outcome.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import '../../../../helpers/stub_auth_repositories.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/promo_banner.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_category_chips.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_flash_sale_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/memory_storefront_persistence.dart';

class _SignedInAuthRepository extends StubAuthRepository {
  @override
  Future<Result<Authenticated?>> checkSession() async =>
      const Success(Authenticated('ui-test-user'));
}

class _SignedInProfileRepository extends StubProfileRepository {
  @override
  Future<Result<Profile?>> readProfile(String userId) async =>
      const Success(Profile(id: 'ui-test-user', fullName: 'UI Tester'));
}

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
  List<String> get defaultCategories =>
      const ['All', 'Silk', 'Cotton', 'Velvet', 'Linen'];

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => [
        {
          'id': 'flash-test',
          'product_id': 'silk-01',
          'discount_pct': 15,
          'starts_at': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'ends_at': DateTime.now()
              .add(const Duration(hours: 2, minutes: 45, seconds: 12))
              .toIso8601String(),
          'is_active': true,
        }
      ];
}

/// MultiBlocProvider with Wishlist/Cart so the Home grid (spec §5)
/// can read wishlist ids and toggle/add per-card. BlocProvider `create:`
/// ensures tree disposal closes the cubits (cancels timers).
Widget _harness({MemoryStorefrontPersistence? persistence}) {
  final store = persistence ?? MemoryStorefrontPersistence();
  return MaterialApp(
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
      ],
      child: const HomePage(),
    ),
  );
}

void main() {
  // Fixed pumps only (never pumpAndSettle): the cubit runs periodic
  // countdown timers, so settle-based pumping would never quiesce.
  testWidgets('Home shows Stitch hero + chips + flash + grid', (tester) async {
    // Tall viewport so the lazy SliverGrid builds all four cards.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(StitchSearchBar), findsOneWidget);
    // Hero fallback until StitchHeroCarousel exists.
    expect(find.byType(PromoBanner), findsOneWidget);
    expect(find.byType(StitchCategoryChips), findsOneWidget);
    // Category names render twice: chip labels + grid card subtitles.
    expect(find.text('Silk'), findsNWidgets(2));
    expect(find.text('Cotton'), findsNWidgets(2));
    expect(find.byType(StitchFlashSaleCard), findsOneWidget);
    expect(find.text('-15%'), findsNWidgets(2)); // header badge + card badge
    expect(find.byType(StitchProductGridCard), findsNWidgets(4));
    // Perf: Home uses lazy SliverGrid (no shrinkWrap) via productGridDelegate.
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    // Live countdown from server flash sale (T1) — flashRemaining driven by loadFlashSales.
    // Pump extra to flush async flash load.
    await tester.pump(const Duration(milliseconds: 100));
    final ctx = tester.element(find.byType(HomePage));
    expect(ctx.read<CatalogCubit>().state.flashRemaining, isNotNull);
    // Flash sale card should be visible with server discount.
    expect(find.byType(StitchFlashSaleCard), findsOneWidget);
  });

  testWidgets('Home greeting uses the authenticated profile first name',
      (tester) async {
    final store = MemoryStorefrontPersistence();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
                create: (_) => CatalogCubit(const _StubRepo())..load()),
            BlocProvider(create: (_) => WishlistCubit(store)),
            BlocProvider(create: (_) => CartCubit(store)),
            BlocProvider(
              create: (_) => AuthCubit(
                authRepository: _SignedInAuthRepository(),
                profileRepository: _SignedInProfileRepository(),
              )..checkSession(),
            ),
          ],
          // 09:00 → morning bucket (UX-044).
          child: HomePage(clock: () => DateTime(2026, 9, 6, 9)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Good morning, UI'), findsOneWidget);
    expect(find.text('Good morning, Ahmed'), findsNothing);
  });

  testWidgets('tapping the Silk chip filters via cubit.select', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // 'Silk' also appears as a grid-card subtitle, so scope to the chips.
    await tester.tap(
      find.descendant(
        of: find.byType(StitchCategoryChips),
        matching: find.text('Silk'),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(HomePage));
    expect(context.read<CatalogCubit>().state.filters.category, 'Silk');
  });
}
