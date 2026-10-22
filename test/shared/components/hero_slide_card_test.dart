import 'package:al_batal_elite/shared/components/app_image.dart';
import 'package:al_batal_elite/shared/components/stitch/hero/gold_pill.dart';
import 'package:al_batal_elite/shared/components/stitch/hero/hero_slide_card.dart';
import 'package:al_batal_elite/shared/components/stitch/stitch_hero_carousel.dart';
import 'package:al_batal_elite/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('promo slide renders the primary gradient background',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        height: 180,
        child: HeroSlideCard(
          slide: StitchHeroSlide.promo(
            eyebrow: 'New Arrival',
            title: 'New Silk Collection',
            subtitle: '20% Off',
            ctaLabel: 'Shop Now',
          ),
        ),
      ),
    ));

    expect(find.byType(AppImage), findsNothing);
    expect(find.text('New Silk Collection'), findsOneWidget);
    expect(find.byType(GoldPill), findsOneWidget);
  });

  testWidgets('product slide paints the swatch, image placeholder and scrim',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        height: 180,
        child: HeroSlideCard(
          slide: StitchHeroSlide(
            imageAsset: 'https://cdn.example.com/fabric.jpg',
            swatchColor: AppColors.primary,
            eyebrow: 'Silk',
            title: 'Royal Emerald Silk',
            subtitle: '1,290 EGP',
            onTap: () => taps++,
          ),
        ),
      ),
    ));

    expect(find.byType(AppImage), findsOneWidget);
    expect(find.byType(ColoredBox), findsWidgets);
    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    // Placeholder icon is built with the image while the remote bytes load.
    expect(find.byIcon(Icons.texture), findsOneWidget);

    await tester.tap(find.byType(HeroSlideCard));
    expect(taps, 1);
  });
}
