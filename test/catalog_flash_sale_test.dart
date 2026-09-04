import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'helpers/stub_auth_repositories.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_flash_sale_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/memory_storefront_persistence.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

const _testProducts = [
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
];

Widget _harness(CatalogRepository repo, MemoryStorefrontPersistence store) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CatalogCubit(repo)..load()),
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
  late MockCatalogRepository mockRepo;

  setUp(() {
    mockRepo = MockCatalogRepository();
    when(() => mockRepo.fetchProducts())
        .thenAnswer((_) async => const Success(_testProducts));
    when(() => mockRepo.fetchCategories())
        .thenAnswer((_) async => const Success(['All', 'Silk', 'Cotton']));
    when(() => mockRepo.findProductById(any())).thenAnswer((inv) {
      final id = inv.positionalArguments[0] as String;
      return _testProducts.where((p) => p.id == id).firstOrNull;
    });
  });

  testWidgets('flash sale banner shows server discount 15% (plan Step1)',
      (tester) async {
    // Server returns 15% sale for p1 — matches plan snippet.
    when(() => mockRepo.getActiveFlashSales()).thenAnswer((_) async => [
          {
            'id': 'flash-1',
            'product_id': 'p1',
            'discount_pct': 15,
            'starts_at': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'ends_at':
                DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            'is_active': true,
          }
        ]);

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    await tester.pumpWidget(_harness(mockRepo, store));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // Banner should show server discount, not hardcoded placeholder.
    expect(find.textContaining('15%'), findsWidgets);
    expect(find.text('-15%'), findsWidgets);
    // Verify cubit actually holds server flashSales.
    final ctx = tester.element(find.byType(HomePage));
    final cubit = ctx.read<CatalogCubit>();
    expect(cubit.state.flashSales, isNotEmpty);
    expect(cubit.state.flashSales.first['discount_pct'], 15);
    expect(cubit.state.flashSales.first['product_id'], 'p1');
  });

  testWidgets('flash sale banner shows distinct server discount 22%',
      (tester) async {
    when(() => mockRepo.getActiveFlashSales()).thenAnswer((_) async => [
          {
            'id': 'flash-2',
            'product_id': 'p1',
            'discount_pct': 22,
            'starts_at': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'ends_at':
                DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
            'is_active': true,
          }
        ]);

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    await tester.pumpWidget(_harness(mockRepo, store));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('22%'), findsWidgets);
    expect(find.text('-22%'), findsWidgets);
    // Ensure old hardcoded 15% not shown when server says 22%.
    expect(find.text('-15%'), findsNothing);
  });

  testWidgets('flash sale countdown ticks from server endsAt', (tester) async {
    final endsAt = DateTime.now().add(const Duration(hours: 1, minutes: 5));
    when(() => mockRepo.getActiveFlashSales()).thenAnswer((_) async => [
          {
            'id': 'flash-3',
            'product_id': 'p1',
            'discount_pct': 10,
            'starts_at': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'ends_at': endsAt.toIso8601String(),
            'is_active': true,
          }
        ]);

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    await tester.pumpWidget(_harness(mockRepo, store));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));

    // Card should be visible with server discount.
    expect(find.text('-10%'), findsWidgets);
    expect(find.byType(StitchFlashSaleCard), findsOneWidget);
    // Countdown derived from server endsAt should be active (~1h05m).
    final ctx = tester.element(find.byType(HomePage));
    final cubit = ctx.read<CatalogCubit>();
    expect(cubit.state.flashRemaining, isNotNull);
    expect(cubit.state.flashRemaining!.inMinutes, greaterThanOrEqualTo(60));
  });
}
