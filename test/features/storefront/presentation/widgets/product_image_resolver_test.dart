import 'package:al_batal_elite/features/storefront/presentation/widgets/product_image_resolver.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('null or empty assets render the texture fallback',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImageResolver(imageColor: 0xFF176B57, asset: null),
        ),
      ),
    );

    expect(find.byIcon(Icons.texture), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImageResolver(imageColor: 0xFF176B57, asset: ''),
        ),
      ),
    );

    expect(find.byIcon(Icons.texture), findsOneWidget);
  });

  testWidgets('https assets go through CachedNetworkImage with fallbacks',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImageResolver(
            imageColor: 0xFF176B57,
            asset: 'https://example.com/fabric.jpg',
            cacheWidth: 420,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://example.com/fabric.jpg');
    expect(image.memCacheWidth, 420);
    expect(image.fadeInDuration, const Duration(milliseconds: 150));

    final context = tester.element(find.byType(ProductImageResolver));
    expect(image.placeholder!(context, image.imageUrl), isA<ColoredBox>());
    expect(
      image.errorWidget!(context, image.imageUrl, Exception('offline')),
      isA<ColoredBox>(),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rejects cleartext http urls in debug builds', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const resolver = ProductImageResolver(
      imageColor: 0xFF176B57,
      asset: 'http://example.com/fabric.jpg',
    );
    expect(() => resolver.build(captured), throwsAssertionError);
  });
}
