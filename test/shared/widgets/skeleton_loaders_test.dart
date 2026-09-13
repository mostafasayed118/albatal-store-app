import 'package:al_batal_elite/shared/widgets/skeleton_loaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  // The skeleton pulse runs a repeating ticker: every test unmounts the
  // tree explicitly so no ticker is left active at test end.
  testWidgets('CatalogSkeleton renders a bone product grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CatalogSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Skeletonizer's public constructor is a factory redirect, so the
    // runtime type is private: assert on the bone content instead.
    expect(find.byWidgetPredicate((w) => w is Bone), findsWidgets);
    expect(find.byType(Card), findsWidgets);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink()); // explicit unmount
  });

  testWidgets('OrdersSkeleton renders bone list tiles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OrdersSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byWidgetPredicate((w) => w is Bone), findsAtLeastNWidgets(4));

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink()); // explicit unmount
  });
}
