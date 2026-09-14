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

void main() {
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
