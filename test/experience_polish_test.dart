import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/home_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_list.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_flash_sale_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/memory_storefront_persistence.dart';
import 'helpers/stub_auth_repositories.dart';

class _MockCatalogRepository extends Mock implements CatalogRepository {}

const _products = [
  Product(
    id: 'p1',
    name: 'Royal Emerald Silk',
    category: 'Silk',
    price: Money.egp(1290),
    imageColor: 0xFF176B57,
  ),
];

Widget _homeHarness(
    _MockCatalogRepository repo, MemoryStorefrontPersistence store) {
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
          )..checkSession(),
        ),
      ],
      child: const HomePage(),
    ),
  );
}

Widget _l10nHarness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('experience polish', () {
    testWidgets(
        'flash-sale add acknowledges itself with a confirmation and updates the cart',
        (tester) async {
      final repo = _MockCatalogRepository();
      when(() => repo.fetchProducts())
          .thenAnswer((_) async => const Success(_products));
      when(() => repo.fetchCategories())
          .thenAnswer((_) async => const Success(['All', 'Silk']));
      when(() => repo.getActiveFlashSales()).thenAnswer((_) async => [
            {
              'id': 'flash-1',
              'product_id': 'p1',
              'discount_pct': 15,
              'starts_at': DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
              'ends_at': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'is_active': true,
            }
          ]);

      final store = MemoryStorefrontPersistence();
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_homeHarness(repo, store));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      // The flash-sale "+" previously added silently.
      await tester.tap(find.descendant(
        of: find.byType(StitchFlashSaleCard),
        matching: find.byIcon(Icons.add),
      ));
      await tester.pump();

      expect(
        find.text('Added to your cart'),
        findsOneWidget,
        reason: 'the add must acknowledge itself (floating snackbar)',
      );
      final ctx = tester.element(find.byType(HomePage));
      expect(ctx.read<CartCubit>().state.items, hasLength(1));
    });

    testWidgets('empty orders tabs invite the user to keep shopping',
        (tester) async {
      await tester.pumpWidget(_l10nHarness(OrderList(
        orders: const [],
        emptyMessage: 'No active orders',
        isCompleted: false,
        scheme: const ColorScheme.light(),
      )));

      expect(find.text('No active orders'), findsOneWidget);
      // The dead-end is gone: a CTA back into the catalog is offered.
      expect(find.text('Continue Shopping'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('the default error state says what to do next', (tester) async {
      await tester.pumpWidget(_l10nHarness(
        FeedbackView(
          type: FeedbackViewType.error,
          // Every real error site wires a recovery action (reload,
          // restore…). The CTA renders only when one exists — by design.
          onAction: () {},
        ),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
        reason: 'errors must point at the recoverable action',
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
