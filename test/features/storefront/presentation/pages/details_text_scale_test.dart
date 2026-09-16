import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/add_to_cart_button.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/related_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/local_catalog_repository.dart';
import '../../../../helpers/app_fonts.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Same provider set as the details page harness (details_page_test.dart),
/// with the page subtree pinned to a fixed 1.4x system text scale.
Widget _harness(String productId) {
  final persistence = MemoryStorefrontPersistence();
  return MaterialApp(
    // The APP theme, not the Material default: `loadAppFonts` only takes
    // effect through a font family the theme declares (Inter/Montserrat).
    // Unthemed, the CTA label measures ~2x its real width and the fit
    // assertion below reports a false ellipsis.
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WishlistCubit(persistence)),
        BlocProvider(create: (_) => CartCubit(persistence)),
      ],
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: DetailsPage(
            id: productId, catalogRepository: LocalCatalogRepository()),
      ),
    ),
  );
}

/// Metered fabric whose line total lands on fractional piasters:
/// 399.50 EGP/m x 2.5 m = 998.75 EGP. Before the money fix the CTA printed the
/// truncated "998 EGY", so this is the amount that made the label longer.
const _metered = Product(
  id: 'silk-metered',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money(39950),
  imageColor: 0xFF176B57,
  sellByLength: true,
  minCutMeters: 0.5,
  stock: {'Emerald-2.5': 5},
);

/// The CTA alone, in a real `bottomNavigationBar` slot under the app theme —
/// whose `minimumSize: Size.fromHeight(50)` is what once forced this button's
/// row to infinite width — at a 1.4x system text scale on a 360dp viewport.
Widget _ctaHarness(DetailsState state) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: BlocProvider(
          create: (_) => CartCubit(MemoryStorefrontPersistence()),
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
      ),
    );

/// Asserts [label] is rendered in full — present, not ellipsized, and inside
/// the 360dp viewport — rather than merely "not overflowing".
void _expectFitsInFull(WidgetTester tester, String label) {
  expect(tester.takeException(), isNull,
      reason: 'the CTA row must not overflow at 1.4 scale');
  expect(find.text(label), findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  expect(paragraph.didExceedMaxLines, isFalse,
      reason: 'the whole amount — piasters included — must stay visible');
  expect(tester.getRect(find.text(label)).right, lessThanOrEqualTo(360),
      reason: 'the label must stay on the 360dp viewport');
}

void main() {
  testWidgets(
      'Details page renders name/price block and CTA without overflow at a '
      '360dp phone viewport with 1.4 system font scale', (tester) async {
    // Real Inter/Montserrat: the CTA's fit claim is only meaningful against
    // the fonts the app ships, not the test font.
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness('silk-01'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);

    // Name/price block: AppBar title + body title → two occurrences.
    expect(find.text('Royal Emerald Silk'), findsNWidgets(2));
    expect(find.text('1290 EGY'), findsOneWidget);
    // CTA line total renders at scale AND in full — with the real fonts
    // loaded, "not ellipsized" is a claim this pin can actually make.
    _expectFitsInFull(tester, 'Add to Cart - 1290 EGY');
  });

  testWidgets(
      'RelatedCard renders name and price without overflow at 1.4 scale '
      'in its 140x200 strip slot', (tester) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: Scaffold(
          body: Center(
            child: RelatedCard(
              product: Product(
                id: 'silk-02',
                name: 'Desert Gold Silk',
                category: 'Silk',
                price: Money.egp(1340),
                imageColor: 0xFFB57A2A,
              ),
              onTap: _noop,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Desert Gold Silk'), findsOneWidget);
    expect(find.textContaining('EGY'), findsOneWidget);
  });

  testWidgets(
      'the Add-to-Cart CTA fits a fractional metered total IN FULL at 1.4 '
      'scale on a 360dp viewport', (tester) async {
    // Real Inter metrics: the amount the money fix made longer must still be
    // readable end to end, not just "not overflowing".
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ctaHarness(const DetailsState(
      status: DetailsStatus.ready,
      product: _metered,
      color: 'Emerald',
      length: '2.5',
    )));

    // 399.50 EGP/m x 2.5 m = 998.75 EGP — the formerly-truncated amount.
    _expectFitsInFull(tester, 'Add to Cart - 998.75 EGY');
  });

  testWidgets(
      'the Add-to-Cart CTA still fits a four-digit metered total at 1.4 scale '
      '(headroom pin)', (tester) async {
    // Quantity 9 → 8988.75 EGP is the widest label still inside the CTA's
    // ~264dp of text room at this scale in Inter. It is the early-warning
    // pin: anything that lengthens the label or widens the lead-in fails
    // here before a real customer sees a clipped price. (Quantity 99, the
    // cubit's clamp ceiling, reaches a 5-digit total and does ellipsize —
    // a designed soft fallback, not an overflow.)
    await loadAppFonts();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ctaHarness(const DetailsState(
      status: DetailsStatus.ready,
      product: _metered,
      color: 'Emerald',
      length: '2.5',
      quantity: 9,
    )));

    _expectFitsInFull(tester, 'Add to Cart - 8988.75 EGY');
  });
}

void _noop() {}
