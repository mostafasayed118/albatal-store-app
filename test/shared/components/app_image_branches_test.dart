import 'package:al_batal_elite/shared/components/app_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double devicePixelRatio = 2.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(devicePixelRatio: devicePixelRatio),
        child: Center(child: child),
      ),
    );

void main() {
  testWidgets(
      'empty source renders the default fallback and honors a custom one',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(source: null)));
    expect(find.byIcon(Icons.texture), findsOneWidget);

    await tester.pumpWidget(_host(const AppImage(
      source: '',
      placeholder: Text('custom fallback'),
    )));
    expect(find.text('custom fallback'), findsOneWidget);
  });

  testWidgets('https source defaults decode bounds from the layout size',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(
      source: 'https://cdn.example.com/fabric.jpg',
      width: 100,
      height: 50,
    )));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    // DPR 2 -> 200x100, well under the 1080 cap.
    expect(image.memCacheWidth, 200);
    expect(image.memCacheHeight, 100);
    expect(image.imageUrl, 'https://cdn.example.com/fabric.jpg');
  });

  testWidgets('explicit cache bounds win and skip the DPR lookup',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(
      source: 'https://cdn.example.com/fabric.jpg',
      cacheWidth: 840,
      cacheHeight: 360,
    )));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.memCacheWidth, 840);
    expect(image.memCacheHeight, 360);
  });

  testWidgets('cleartext http source is rejected with an assertion',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(
      source: 'http://cdn.example.com/fabric.jpg',
    )));
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('non-svg local asset is rejected with an assertion',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(source: 'assets/a.png')));
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('local svg renders an SvgPicture with its semantics label',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(
      source: 'assets/images/onboarding/logo.svg',
      semanticsLabel: 'Al Batal logo',
    )));

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.semanticsLabel, 'Al Batal logo');

    // The loading placeholder is the shared texture fallback.
    final placeholder =
        svg.placeholderBuilder!(tester.element(find.byType(SvgPicture)));
    expect(placeholder, isA<Widget>());
  });

  testWidgets('network placeholder and error builders use the fallback',
      (tester) async {
    await tester.pumpWidget(_host(const AppImage(
      source: 'https://cdn.example.com/fabric.jpg',
    )));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    final context = tester.element(find.byType(CachedNetworkImage));
    final placeholder = image.placeholder!(context, '');
    final error = image.errorWidget!(context, '', Exception('offline'));

    await tester.pumpWidget(_host(placeholder));
    expect(find.byIcon(Icons.texture), findsOneWidget);

    await tester.pumpWidget(_host(error));
    expect(find.byIcon(Icons.texture), findsOneWidget);
  });
}
