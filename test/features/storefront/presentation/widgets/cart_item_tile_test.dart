import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/cart_item_tile.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/quantity_stepper.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

CartItem _item({int quantity = 2, bool sample = false}) => CartItem(
      product: products.first,
      color: 'Emerald',
      length: sample ? 'sample' : '2m',
      quantity: quantity,
      sample: sample,
    );

Widget _harness(CartItem item, MemoryStorefrontPersistence store) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => _seededCart(store, item)),
          BlocProvider(create: (_) => WishlistCubit(store)),
        ],
        child: Scaffold(body: CartItemTile(item: item)),
      ),
    );

CartCubit _seededCart(MemoryStorefrontPersistence store, CartItem item) {
  final cubit = CartCubit(store);
  if (item.sample) {
    cubit.addSample(item.product, color: item.color);
  } else {
    cubit.add(
      item.product,
      color: item.color,
      length: item.length,
      quantity: item.quantity,
    );
  }
  return cubit;
}

CartCubit _cart(WidgetTester tester) =>
    tester.element(find.byType(CartItemTile)).read<CartCubit>();

WishlistCubit _wishlist(WidgetTester tester) =>
    tester.element(find.byType(CartItemTile)).read<WishlistCubit>();

void main() {
  testWidgets('renders the variant, line total, and quantity stepper',
      (tester) async {
    await tester.pumpWidget(
      _harness(_item(), MemoryStorefrontPersistence()),
    );

    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Emerald · 2m'), findsOneWidget);
    expect(find.text('2,580 EGP'), findsOneWidget);
    expect(find.byType(QuantityStepper), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Save for Later'), findsOneWidget);
  });

  testWidgets('incrementing the stepper updates the cart line', (tester) async {
    await tester.pumpWidget(
      _harness(_item(), MemoryStorefrontPersistence()),
    );

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    expect(_cart(tester).state.items.single.quantity, 3);
  });

  testWidgets('decrementing the stepper updates the cart line', (tester) async {
    await tester.pumpWidget(
      _harness(_item(), MemoryStorefrontPersistence()),
    );

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();

    expect(_cart(tester).state.items.single.quantity, 1);
  });

  testWidgets('remove drops the line from the cart', (tester) async {
    await tester.pumpWidget(
      _harness(_item(), MemoryStorefrontPersistence()),
    );

    await tester.tap(find.text('Remove'));
    await tester.pump();

    expect(_cart(tester).state.items, isEmpty);
  });

  testWidgets('save for later toggles the wishlist and drops the line',
      (tester) async {
    await tester.pumpWidget(
      _harness(_item(), MemoryStorefrontPersistence()),
    );

    await tester.tap(find.text('Save for Later'));
    await tester.pump();

    expect(_wishlist(tester).state.ids, {'silk-01'});
    expect(_cart(tester).state.items, isEmpty);
  });

  testWidgets('sample lines show the Sample label and no stepper',
      (tester) async {
    await tester.pumpWidget(
      _harness(_item(sample: true), MemoryStorefrontPersistence()),
    );

    expect(find.text('Emerald · Sample'), findsOneWidget);
    expect(find.byType(QuantityStepper), findsNothing);
    expect(find.text('0 EGP'), findsOneWidget);
  });

  testWidgets('swiping away removes the line and offers an undo',
      (tester) async {
    await tester.pumpWidget(
      _harness(_item(), MemoryStorefrontPersistence()),
    );

    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(_cart(tester).state.items, isEmpty);
    expect(find.text('Remove Royal Emerald Silk'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    final restored = _cart(tester).state.items.single;
    expect(restored.product.id, 'silk-01');
    expect(restored.quantity, 2);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('undoing a swiped sample line restores the sample',
      (tester) async {
    await tester.pumpWidget(
      _harness(_item(sample: true), MemoryStorefrontPersistence()),
    );

    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(_cart(tester).state.items, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    final restored = _cart(tester).state.items.single;
    expect(restored.sample, isTrue);
    expect(restored.quantity, 1);

    await tester.pump(const Duration(seconds: 5));
  });
}
