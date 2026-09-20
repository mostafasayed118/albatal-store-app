import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/image_gallery.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/zoom_gallery.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// No `imageAsset`/`images`: the gallery resolves to a single empty slot
/// and every resolver path renders the texture fallback — deterministic,
/// no image decode in tests (photo_view with real loaders needs a
/// special binding).
const _product = Product(
  id: 'zoom-test',
  name: 'Zoom Test Fabric',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF176B57,
);

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Future<void> _openViewer(WidgetTester tester) async {
  await tester.pumpWidget(_harness(const ImageGallery(product: _product)));
  await tester.tap(find.byType(GestureDetector).first);
  await tester.pumpAndSettle();
}

Product _widthProduct({String? primary, List<String> images = const []}) =>
    Product(
      id: 'widths',
      name: 'Widths',
      category: 'Silk',
      price: const Money.egp(100),
      imageColor: 0xFF176B57,
      imageAsset: primary,
      images: images,
    );

void main() {
  // Audit 2026-09-14 P0-4: the mapper hands the primary over at the GRID budget
  // (420) while the gallery list carries the DETAIL render (720), so the same
  // photo reaches this widget under two different URLs. Comparing the URLs
  // literally read that as two photos and showed the first one twice.
  group('ImageGallery.resolveImages — same photo, two width budgets', () {
    const grid =
        'https://cdn.test/render/image/public/product-images/p/a.jpg?width=420';
    const detailA =
        'https://cdn.test/render/image/public/product-images/p/a.jpg?width=720';
    const detailB =
        'https://cdn.test/render/image/public/product-images/p/b.jpg?width=720';

    test('a width-bounded primary is not duplicated as slide one', () {
      final images = ImageGallery.resolveImages(
        _widthProduct(primary: grid, images: const [detailA, detailB]),
      );

      expect(images, const [detailA, detailB],
          reason: 'the gallery should serve the 720 renders, not the 420 card '
              'copy, and must not add a third slide');
    });

    test('an asset primary already in the list is still deduped', () {
      final images = ImageGallery.resolveImages(
        _widthProduct(
          primary: 'assets/images/1.svg',
          images: const ['assets/images/1.svg', 'assets/images/2.svg'],
        ),
      );

      expect(images, const ['assets/images/1.svg', 'assets/images/2.svg']);
    });

    test('an asset primary absent from the list is still prepended', () {
      final images = ImageGallery.resolveImages(
        _widthProduct(
          primary: 'assets/images/1.svg',
          images: const ['assets/images/2.svg'],
        ),
      );

      expect(images, const ['assets/images/1.svg', 'assets/images/2.svg']);
    });

    test('a product with only a primary keeps exactly one slide', () {
      expect(
        ImageGallery.resolveImages(_widthProduct(primary: grid)),
        const [grid],
      );
    });

    test('no media at all still yields the one empty fallback slot', () {
      expect(ImageGallery.resolveImages(_widthProduct()), const ['']);
    });
  });

  testWidgets('tapping the hero image pushes the fullscreen zoom viewer',
      (tester) async {
    await _openViewer(tester);

    expect(find.byType(ZoomGallery), findsOneWidget);
    // Close affordance with localized tooltip.
    expect(find.byTooltip('Close'), findsOneWidget);
    // Hint copy is shown (single image: zoom hint only, no swipe hint).
    expect(find.text('Pinch to zoom'), findsOneWidget);
    expect(find.textContaining('Swipe to browse photos'), findsNothing);
  });

  testWidgets('viewer exposes a dialog semantics label', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openViewer(tester);

    expect(find.bySemanticsLabel('Product image viewer'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('close button pops the viewer back to the gallery',
      (tester) async {
    await _openViewer(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(ZoomGallery), findsNothing);
    expect(find.byType(ImageGallery), findsOneWidget);
  });

  testWidgets('Escape closes the viewer', (tester) async {
    await _openViewer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(ZoomGallery), findsNothing);
  });

  testWidgets('multi-image viewer shows counter and swipe hint',
      (tester) async {
    await tester.pumpWidget(
      _harness(const ZoomGallery(
        images: ['', '', ''],
        initialIndex: 1,
        imageColor: 0xFF176B57,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(
      find.text('Pinch to zoom · Swipe to browse photos'),
      findsOneWidget,
    );
  });
}
