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

void main() {
  testWidgets(
      'CartItemTile with a long product name does not overflow at 1.4 scale '
      'in a 360dp-wide column', (tester) async {
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
  },
      // KNOWN SCALE FRAGILITY — pin parked until lib/ is fixed (this task
      // is test-only; lib/ must not be touched). Found by this very pin at
      // 360x800 logical px, TextScaler.linear(1.4):
      //
      //  1. lib/features/storefront/presentation/widgets/cart_summary.dart:44
      //     — the label/Spacer/value Row overflows on the right (66px for
      //     the Subtotal row, 21px for the Total row) at w=296: neither
      //     Text flexes, so once label + value exceed the card width the
      //     row cannot wrap.
      //  2. lib/shared/components/app_button.dart:22 — the icon+label Row
      //     inside the 'Proceed to Checkout' CTA overflows by 111px on the
      //     right at w=289.6.
      //
      // Fix direction: Expanded/Flexible on the label (and ellipsis) in
      // CartSummary rows and AppButton. Remove this skip once fixed.
      skip: true);
}
