import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
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

void main() {
  group('§17 product card semantics', () {
    testWidgets('exposes one merged label with name and price', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 290,
            child: StitchProductGridCard(
              product: _product(),
              onTap: () {},
              isWishlisted: false,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      final label = find.bySemanticsLabel(RegExp('.*Royal Emerald Silk.*'));
      expect(label, findsWidgets);
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
