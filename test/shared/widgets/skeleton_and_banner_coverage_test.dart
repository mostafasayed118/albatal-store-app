import 'package:al_batal_elite/shared/widgets/environment_banner.dart';
import 'package:al_batal_elite/shared/widgets/skeleton/orders_skeleton.dart';
import 'package:al_batal_elite/shared/widgets/skeleton/static_tile_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reduce-motion orders skeleton renders static tiles',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: OrdersSkeleton(tileCount: 3),
      ),
    ));
    await tester.pump();

    expect(find.byType(StaticTileSkeleton), findsNWidgets(3));
    expect(find.byType(Card), findsNWidgets(3));
  });

  testWidgets('development build wraps content in the environment banner',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EnvironmentBanner(child: Text('app content')),
    ));

    expect(find.byType(Banner), findsOneWidget);
    expect(find.text('app content'), findsOneWidget);
    expect(
        tester.widget<Banner>(find.byType(Banner)).message, startsWith('DEV'));
  });
}
