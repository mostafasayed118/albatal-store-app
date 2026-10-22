import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/image_gallery.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/zoom_gallery.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id, {required List<String> images}) => Product(
      id: id,
      name: id,
      category: 'Silk',
      price: const Money.egp(100),
      imageColor: 0xFF176B57,
      images: images,
    );

Widget _harness(Product product) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ImageGallery(product: product)),
    );

void main() {
  testWidgets('multi-image gallery renders dots and reports page changes',
      (tester) async {
    await tester.pumpWidget(
      _harness(_product('multi', images: const ['', '', ''])),
    );
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('a new product resets the gallery image list', (tester) async {
    await tester.pumpWidget(
      _harness(_product('first', images: const ['', ''])),
    );
    await tester.pump();

    await tester.pumpWidget(
      _harness(_product('second', images: const [''])),
    );
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('tapping a multi-image slide opens the zoom viewer',
      (tester) async {
    await tester.pumpWidget(
      _harness(_product('multi', images: const ['', ''])),
    );
    await tester.pump();

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.byType(ZoomGallery), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(ZoomGallery), findsNothing);
  });
}
