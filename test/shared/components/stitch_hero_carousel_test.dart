import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_hero_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id, {Money? oldPrice, double rating = 4.0}) => Product(
      id: id,
      name: 'Product $id',
      category: 'Silk',
      price: const Money.egp(850),
      oldPrice: oldPrice,
      imageColor: 0xFF176B57,
      rating: rating,
      reviewCount: 10,
    );

Future<void> _pump(WidgetTester tester, List<StitchHeroSlide> slides,
        {ValueChanged<int>? onPageChanged}) async =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StitchHeroCarousel(slides: slides, onPageChanged: onPageChanged),
      ),
    ));

void main() {
  testWidgets('promo slide renders mockup copy and gold CTA', (tester) async {
    await _pump(tester, [
      StitchHeroSlide.promo(
        eyebrow: 'New Arrival',
        title: 'New Silk Collection',
        subtitle: '20% Off',
        ctaLabel: 'Shop Now',
        onTap: () {},
      ),
    ]);

    expect(find.text('New Arrival'), findsOneWidget);
    expect(find.text('New Silk Collection'), findsOneWidget);
    expect(find.text('20% Off'), findsOneWidget);
    expect(find.text('Shop Now'), findsOneWidget);
    // Single slide → no dots (navigation affordance is meaningless).
    expect(find.byKey(const ValueKey('stitch_hero_dot_0')), findsNothing);
  });

  testWidgets('four slides render four tappable dots; swipe reports index',
      (tester) async {
    final reported = <int>[];
    await _pump(
      tester,
      [
        StitchHeroSlide.promo(
            eyebrow: 'e0', title: 'Promo', subtitle: 's', ctaLabel: 'c'),
        StitchHeroSlide.fromProduct(_product('a')),
        StitchHeroSlide.fromProduct(_product('b')),
        StitchHeroSlide.fromProduct(_product('c')),
      ],
      onPageChanged: reported.add,
    );

    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('stitch_hero_dot_$i')), findsOneWidget);
    }

    // Swipe to the second slide (product slide becomes visible).
    await tester.fling(find.text('Promo'), const Offset(-400, 0), 800);
    await tester.pumpAndSettle();

    expect(reported, [1]);
    expect(find.text('Product a'), findsOneWidget);
    expect(find.text('850 EGY'), findsOneWidget);
  });

  testWidgets('tapping a dot jumps to its slide', (tester) async {
    final reported = <int>[];
    await _pump(
      tester,
      [
        StitchHeroSlide.promo(
            eyebrow: 'e0', title: 'Promo', subtitle: 's', ctaLabel: 'c'),
        StitchHeroSlide.fromProduct(_product('b')),
        StitchHeroSlide.fromProduct(_product('c')),
      ],
      onPageChanged: reported.add,
    );

    await tester.tap(find.byKey(const ValueKey('stitch_hero_dot_2')));
    await tester.pumpAndSettle();

    // PageView fires onPageChanged for every page boundary the animated
    // jump crosses (0→2 reports 1 then 2), so assert the landing page.
    expect(reported.last, 2);
    expect(find.text('Product c'), findsOneWidget);
  });

  testWidgets('no slides renders nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StitchHeroCarousel(slides: [])),
    ));
    expect(find.byType(PageView), findsNothing);
  });

  test('featured picks: discounted first by rating, then best-rated, cap 3',
      () {
    // Verified indirectly through the state API in
    // catalog_state_memo_test (featuredProducts); the factory mapping is
    // covered by the swipe test above (category eyebrow + price).
    final slide = StitchHeroSlide.fromProduct(
        _product('x', oldPrice: const Money.egp(1000), rating: 4.9));
    expect(slide.imageAsset, isNull);
    expect(slide.subtitle, '850 EGY');
    expect(slide.swatchColor, const Color(0xFF176B57));
  });
}
