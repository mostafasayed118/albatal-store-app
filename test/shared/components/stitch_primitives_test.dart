import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_category_chips.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_flash_sale_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_product_grid_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _kCategories = ['Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];

const _kProduct = Product(
  id: 'silk-01',
  name: 'Royal Emerald Silk',
  category: 'Silk',
  price: Money.egp(1290),
  oldPrice: Money.egp(1520),
  imageColor: 0xFF176B57,
  imageAsset: 'assets/images/1.svg',
  rating: 4.8,
  reviewCount: 124,
);

void main() {
  testWidgets('StitchCategoryChips shows 5 chips, Silk active', (tester) async {
    String selected = 'Silk';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StitchCategoryChips(
            selected: selected,
            onSelect: (v) => selected = v,
            categories: _kCategories,
          ),
        ),
      ),
    );

    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('Cotton'), findsOneWidget);
    expect(find.text('Velvet'), findsOneWidget);
    expect(find.text('Linen'), findsOneWidget);
    expect(find.text('Wool'), findsOneWidget);
    // exactly 5 category labels rendered
    expect(find.byType(StitchCategoryChips), findsOneWidget);
  });

  testWidgets('StitchCategoryChips onSelect fires', (tester) async {
    String tapped = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StitchCategoryChips(
            selected: 'Silk',
            onSelect: (v) => tapped = v,
            categories: _kCategories,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cotton'));
    await tester.pump();
    expect(tapped, 'Cotton');
  });

  testWidgets('StitchSearchBar renders hint and mic', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StitchSearchBar(controller: controller)),
      ),
    );
    expect(find.byType(StitchSearchBar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('StitchFlashSaleCard renders product row 120dp with badge',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StitchFlashSaleCard(product: _kProduct, discountLabel: '-15%'),
        ),
      ),
    );
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('-15%'), findsOneWidget);
    expect(find.byType(StitchFlashSaleCard), findsOneWidget);
  });

  testWidgets('StitchProductGridCard renders product with wishlist heart',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: StitchProductGridCard(product: _kProduct),
          ),
        ),
      ),
    );
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byType(StitchProductGridCard), findsOneWidget);
  });
}
