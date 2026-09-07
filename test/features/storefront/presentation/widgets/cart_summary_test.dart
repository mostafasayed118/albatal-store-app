import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/cart_summary.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';

CartState _cart({required bool premium}) => CartState(
      [
        CartItem(
          product: products.first,
          color: 'Emerald',
          length: '2m',
        )
      ],
      status: CartStatus.ready,
      isPremiumMember: premium,
    );

Widget _harness(CartState state) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CartSummary(state),
      ),
    );

void main() {
  testWidgets('premium members see Free instead of the shipping fee',
      (tester) async {
    await tester.pumpWidget(_harness(_cart(premium: true)));

    expect(find.text('Free'), findsOneWidget);
    // 75 EGY is the standard flat estimate; a premium member's total
    // equals their subtotal.
    expect(find.text('75 EGY'), findsNothing);
  });

  testWidgets('standard members still see the shipping fee', (tester) async {
    await tester.pumpWidget(_harness(_cart(premium: false)));

    expect(find.text('Free'), findsNothing);
    expect(find.text('75 EGY'), findsOneWidget);
  });
}
