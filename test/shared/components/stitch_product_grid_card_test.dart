import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_fonts.dart';

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
      // The APP theme, not the Material default: `loadAppFonts` only takes
      // effect through a font family the theme declares (Inter/Montserrat).
      // Unthemed, text falls back to the test font — 2x wider — and the pin
      // measures the harness instead of the app.
      theme: AppTheme.light(),
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

/// PRICE CLIPPING (found and fixed 2026-09-16) — the overflow pins could not
/// see this, because a clipped amount raises no exception and "no RenderFlex
/// overflow" is not a fit check.
///
/// The price row was a Row that split the cell's inner width evenly between
/// the price and the struck-through old price. With a discount present that
/// left the amount short in the real fonts, in this exact 158dp cell:
///
///   theme + Inter            intrinsic / slot
///     price @1.0x            66.9 / 66.0  -> clipped
///     price @1.4x            93.2 / 66.0  -> clipped
///   (unthemed = test font:  112.8 / 157.6, which is why the old harness
///    could not tell either way)
///
/// The row is now a Wrap: each amount takes the width it needs and the old
/// price drops to a second line when it no longer fits beside the price. At
/// the default scale both still share one line, so the shipped look is
/// unchanged. These pins assert the amounts render IN FULL at both scales.
void _expectPriceVisibleInFull(WidgetTester tester, String amount) {
  expect(find.text(amount), findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(find.text(amount));
  expect(paragraph.didExceedMaxLines, isFalse,
      reason: '$amount must not be clipped in the 158dp grid cell');
}

void main() {
  testWidgets('no overflow at the device-found cell size (158 x 232.35)',
      (tester) async {
    // Real Inter/Montserrat: the cell is 158dp wide, so the amount's width
    // has to be the width a device sees.
    await loadAppFonts();
    await tester.pumpWidget(_harness(
      StitchProductGridCard(
        product: _product(name: 'Royal Emerald Silk Deluxe Weave'),
      ),
    ));
    expect(tester.takeException(), isNull);
    _expectPriceVisibleInFull(tester, '1,450 EGP');
    _expectPriceVisibleInFull(tester, '1,900 EGP');
  });

  testWidgets('no overflow with large system font scale', (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(_harness(
      StitchProductGridCard(
        product: _product(name: 'Royal Emerald Silk Deluxe Weave'),
      ),
      textScaler: const TextScaler.linear(1.4),
    ));
    expect(tester.takeException(), isNull);
    // 1.4x is where the old Row clipped hardest (~27dp short).
    _expectPriceVisibleInFull(tester, '1,450 EGP');
    _expectPriceVisibleInFull(tester, '1,900 EGP');
  });

  testWidgets('renders name, category and price', (tester) async {
    await tester.pumpWidget(_harness(StitchProductGridCard(
      product: _product(),
    )));
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('Silk'), findsOneWidget);
    _expectPriceVisibleInFull(tester, '1,450 EGP');
  });
}
