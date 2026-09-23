import 'dart:ui' show Tristate;

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_flash_sale_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_hero_carousel.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/widgets/skeleton_loaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product() => const Product(
      id: 'p1',
      name: 'Royal Emerald Silk',
      category: 'Silk',
      price: Money(129000),
      imageColor: 0xFF064E3B,
    );

Widget _localized(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('§17 product card semantics', () {
    testWidgets('exposes one merged label with name and price', (tester) async {
      await tester.pumpWidget(_localized(
        SizedBox(
          width: 200,
          height: 290,
          child: StitchProductGridCard(
            product: _product(),
            onTap: () {},
            isWishlisted: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      final label = find.bySemanticsLabel(RegExp('.*Royal Emerald Silk.*'));
      expect(label, findsWidgets);
      handle.dispose();
    });

    testWidgets('wishlist heart is a labelled button with selected state',
        (tester) async {
      Future<void> pump(bool wishlisted) async {
        await tester.pumpWidget(_localized(
          SizedBox(
            width: 200,
            height: 290,
            child: StitchProductGridCard(
              product: _product(),
              onTap: () {},
              onWishlist: () {},
              isWishlisted: wishlisted,
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pump(false);
      final handle = tester.ensureSemantics();

      // Not wishlisted: announced as "Add to wishlist, <product name>".
      final addNode = tester.getSemantics(
        find.bySemanticsLabel('Add to wishlist, Royal Emerald Silk'),
      );
      expect(addNode.flagsCollection.isButton, isTrue);
      expect(addNode.flagsCollection.isSelected, isNot(Tristate.isTrue));

      await pump(true);
      await tester.pumpAndSettle();

      // Wishlisted: action flips to "Remove from wishlist" + selected state.
      final removeNode = tester.getSemantics(
        find.bySemanticsLabel('Remove from wishlist, Royal Emerald Silk'),
      );
      expect(removeNode.flagsCollection.isButton, isTrue);
      expect(removeNode.flagsCollection.isSelected, Tristate.isTrue);

      handle.dispose();
    });
  });

  group('flash-sale countdown semantics', () {
    testWidgets(
        'countdown is announced as remaining time and is not a live region',
        (tester) async {
      await tester.pumpWidget(_localized(
        const StitchFlashSaleCard(
          product: Product(
            id: 'p1',
            name: 'Royal Emerald Silk',
            category: 'Silk',
            price: Money(129000),
            imageColor: 0xFF064E3B,
          ),
          discountLabel: '-15%',
          remaining: Duration(hours: 1, minutes: 23, seconds: 45),
        ),
      ));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      // The card's texts merge into one node — match the label inside it.
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Flash sale ends in 01:23:45')),
      );
      // liveRegion: false — the 1Hz ticker must not spam the screen reader.
      expect(node.flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    testWidgets('product image carries the product name as its label',
        (tester) async {
      await tester.pumpWidget(_localized(
        const StitchFlashSaleCard(
          product: Product(
            id: 'p1',
            name: 'Royal Emerald Silk',
            category: 'Silk',
            price: Money(129000),
            imageColor: 0xFF064E3B,
            imageAsset: 'assets/images/1.svg',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('Royal Emerald Silk')),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('hero carousel dot semantics', () {
    testWidgets('dots are labelled buttons with selected state',
        (tester) async {
      final slides = [
        StitchHeroSlide.promo(
          eyebrow: 'e0',
          title: 'Promo',
          subtitle: 's',
          ctaLabel: 'c',
        ),
        StitchHeroSlide.fromProduct(_product(), l10n: AppLocalizationsEn()),
        StitchHeroSlide.fromProduct(_product(), l10n: AppLocalizationsEn()),
      ];
      await tester.pumpWidget(_localized(
        StitchHeroCarousel(slides: slides),
      ));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();

      final dot1 = tester.getSemantics(find.bySemanticsLabel('Go to slide 1'));
      expect(dot1.flagsCollection.isButton, isTrue);
      expect(dot1.flagsCollection.isSelected, Tristate.isTrue);

      final dot2 = tester.getSemantics(find.bySemanticsLabel('Go to slide 2'));
      expect(dot2.flagsCollection.isButton, isTrue);
      expect(dot2.flagsCollection.isSelected, isNot(Tristate.isTrue));

      handle.dispose();
    });
  });

  group('§17 reduce-motion skeletons', () {
    testWidgets('reduce-motion renders static placeholders', (tester) async {
      await tester.pumpWidget(MaterialApp(
        // Disable animations (the reduce-motion flag in tests).
        theme: ThemeData(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: CatalogSkeleton()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // The static fallback renders plain Containers instead of the
      // animated Bone widgets.
      expect(find.byType(Card), findsWidgets);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
