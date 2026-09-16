import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
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

/// KNOWN DEFECT, measured but deliberately NOT pinned here (2026-09-16).
///
/// The price row splits the cell's inner width evenly between the price and
/// the struck-through old price (`Flexible` + `maxLines: 1` + ellipsis on
/// both). In the real fonts, with a discount present, that leaves the price
/// 0.9dp short at the default scale and ~27dp short at 1.4x:
///
///   theme + Inter, cell 158dp  ->  intrinsic / slot
///     price     @1.0x  ``1450 EGY``  66.9 / 66.0  -> clipped
///     price     @1.4x  ``1450 EGY``  93.2 / 66.0  -> clipped
///   (unthemed, i.e. test font, the same string measures 112.8 / 157.6)
///
/// So the amount is silently ellipsized in the grid, and this file's pins —
/// which only ever asserted "no overflow exception" — could not see it. It is
/// PRE-EXISTING (the amounts here are whole pounds; this branch does not touch
/// the card) and fixing it means re-balancing the row, which is a design call.
/// Reported to the owner instead of pinned, so the test does not lock in the
/// clipped rendering as correct.
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
    // The amount reaches the widget tree intact (it is the RENDERING that is
    // clipped, per the KNOWN DEFECT note above).
    expect(find.text('1450 EGY'), findsOneWidget);
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
    expect(find.text('1450 EGY'), findsOneWidget);
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
