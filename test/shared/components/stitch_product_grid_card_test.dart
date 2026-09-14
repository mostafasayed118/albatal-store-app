import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression for the device-found RenderFlex overflow (2026-09-13):
/// on a 360dp-wide phone the grid cell is 158 x 232.4 (aspectRatio .68)
/// and the fixed 1:1 media + intrinsic text block overflowed by 7.6px.
/// The card now flexes the media, so no cell size or font scale can
/// overflow.
Product _product(
        {String name = 'Royal Emerald Silk', String category = 'Silk'}) =>
    Product(
      id: 'p-overflow',
      name: name,
      category: category,
      price: const Money.egp(1450),
      oldPrice: const Money.egp(1900),
      imageColor: 0xFF2E5E4E,
    );

Widget _harness(Widget card, {TextScaler textScaler = TextScaler.noScaling}) =>
    MaterialApp(
      // The card reads AppLocalizations for the wishlist heart label.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 158,
              height: 232.35,
              child: card,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('no overflow at the device-found cell size (158 x 232.35)',
      (tester) async {
    await tester.pumpWidget(_harness(
      StitchProductGridCard(
        product: _product(name: 'Royal Emerald Silk Deluxe Weave'),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow with large system font scale', (tester) async {
    await tester.pumpWidget(_harness(
      StitchProductGridCard(
        product: _product(name: 'Royal Emerald Silk Deluxe Weave'),
      ),
      textScaler: const TextScaler.linear(1.4),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders name, category and price', (tester) async {
    await tester.pumpWidget(_harness(StitchProductGridCard(
      product: _product(),
    )));
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('1450 EGY'), findsOneWidget);
  });
}
