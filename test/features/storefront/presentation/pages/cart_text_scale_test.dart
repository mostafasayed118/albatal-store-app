import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/cart_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/cart_item_tile.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/cart_summary.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/quantity_stepper.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/app_fonts.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// A deliberately long product name: scale-fragile tiles usually break on
/// wrapping text inside a Row, so the pin uses worst-case copy.
const _longNameProduct = Product(
  id: 'silk-long',
  name: 'Royal Emerald Silk Deluxe Weave Grand Ottoman Collection',
  category: 'Silk',
  price: Money.egp(1290),
  oldPrice: Money.egp(1520),
  imageColor: 0xFF176B57,
  sizes: ['1m', '2m', '5m'],
  colors: ['Emerald', 'Gold', 'Ivory'],
);

/// A metered fabric whose line total lands on fractional piasters:
/// 399.50 EGP/m x 2.5 m = 998.75 EGP. The money fix prints that in full, so
/// the tile and the totals row carry a LONGER amount than the whole-pound
/// figures the sibling pins use.
const _meteredProduct = Product(
  id: 'silk-metered',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money(39950),
  imageColor: 0xFF176B57,
  sellByLength: true,
  minCutMeters: 0.5,
  stock: {'Emerald-2.5': 5},
);

void main() {
  testWidgets(
      'CartItemTile with a long product name does not overflow at 1.4 scale '
      'in a 360dp-wide column', (tester) async {
    // Real Inter/Montserrat: measured against the fonts the app ships.
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    final cart = CartCubit(store);
    cart.add(_longNameProduct, color: 'Emerald', length: '2m', quantity: 3);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cart),
          BlocProvider(create: (_) => WishlistCubit(store)),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: const [
                CartItemTile(
                  item: CartItem(
                    product: _longNameProduct,
                    color: 'Emerald',
                    length: '2m',
                    quantity: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Long product name still renders (wrapped, not clipped away).
    expect(find.text(_longNameProduct.name), findsOneWidget);
    // Quantity stepper still mounted at scale.
    expect(find.byType(QuantityStepper), findsOneWidget);
  });

  testWidgets(
      'Cart page renders item tile, quantity stepper and totals row without '
      'overflow at a 360dp phone viewport with 1.4 system font scale',
      (tester) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    final cart = CartCubit(store);
    cart.add(_longNameProduct, color: 'Emerald', length: '2m', quantity: 3);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cart),
          BlocProvider(create: (_) => WishlistCubit(store)),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: CartPage(),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CartItemTile), findsOneWidget);
    expect(find.byType(QuantityStepper), findsOneWidget);

    // The trailing totals row: scroll it into view (lazy ListView) and pin
    // the Subtotal/Shipping/Total rows render at scale.
    await tester.scrollUntilVisible(
      find.byType(CartSummary),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CartSummary), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('EGY'), findsWidgets);
  });

  testWidgets(
      'Cart tile and totals row carry a fractional piaster amount without '
      'overflow at 1.4 scale on a 360dp viewport', (tester) async {
    // Real Inter metrics, so the amount's width is the width a device sees.
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = MemoryStorefrontPersistence();
    final cart = CartCubit(store);
    cart.add(_meteredProduct, color: 'Emerald', length: '2.5');

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cart),
          BlocProvider(create: (_) => WishlistCubit(store)),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: CartPage(),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);

    // 998.75 EGP in the tile: the amount the truncating formatter printed as
    // "998 EGY". (The same string heads the totals row, so this is ≥1.)
    expect(find.text('998.75 EGY'), findsWidgets);
    expect(find.byType(QuantityStepper), findsOneWidget);

    // It must also flow through the totals: 998.75 + 75.00 shipping =
    // 1073.75, not a floored 1073.
    await tester.scrollUntilVisible(
      find.byType(CartSummary),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('1073.75 EGY'), findsOneWidget);
    expect(
        tester.getRect(find.text('1073.75 EGY')).right, lessThanOrEqualTo(360),
        reason: 'the amount must stay inside the 360dp viewport');
  });
}
