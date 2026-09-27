import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/add_to_cart_button.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/memory_storefront_persistence.dart';

const _inStock = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
  colors: ['Emerald', 'Gold'],
  sizes: ['1m', '2m'],
  stock: {'Emerald-1m': 10, 'Gold-2m': 4},
);

const _outOfStock = Product(
  id: 'silk-02',
  name: 'Bare Silk',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
  colors: ['Emerald'],
  sizes: ['1m'],
  stock: {},
);

DetailsState _stateFor(Product product) => DetailsState(
      status: DetailsStatus.ready,
      product: product,
      color: 'Emerald',
      length: '1m',
      quantity: 1,
    );

/// The details CTA bar in a real `bottomNavigationBar` slot under the app
/// theme, with an injectable [CartCubit] so taps are observable.
Widget _barHarness(CartCubit cart, DetailsState state) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cart,
        child: Scaffold(
          bottomNavigationBar: Builder(
            builder: (context) => AddToCartButton(
              state: state,
              l: AppLocalizations.of(context)!,
              scheme: Theme.of(context).colorScheme,
            ),
          ),
        ),
      ),
    );

void main() {
  group('details sample order button (swatch-kit)', () {
    testWidgets('tapping it adds one sample line and confirms',
        (tester) async {
      final cart = CartCubit(MemoryStorefrontPersistence());
      addTearDown(cart.close);
      await tester.pumpWidget(_barHarness(cart, _stateFor(_inStock)));
      await tester.pumpAndSettle();

      expect(find.text('Order fabric sample'), findsOneWidget);

      await tester.tap(find.text('Order fabric sample'));
      await tester.pump();

      expect(cart.state.items, hasLength(1));
      final item = cart.state.items.single;
      expect(item.sample, isTrue);
      expect(item.color, 'Emerald');
      expect(find.text('Sample added to your cart'), findsOneWidget);
    });

    testWidgets('re-tapping is an idempotent no-op', (tester) async {
      final cart = CartCubit(MemoryStorefrontPersistence());
      addTearDown(cart.close);
      await tester.pumpWidget(_barHarness(cart, _stateFor(_inStock)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Order fabric sample'));
      await tester.pump();
      await tester.tap(find.text('Order fabric sample'));
      await tester.pump();

      expect(cart.state.items, hasLength(1));
    });

    testWidgets('hidden when the variant is out of stock', (tester) async {
      final cart = CartCubit(MemoryStorefrontPersistence());
      addTearDown(cart.close);
      await tester.pumpWidget(_barHarness(cart, _stateFor(_outOfStock)));
      await tester.pumpAndSettle();

      expect(find.text('Order fabric sample'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
