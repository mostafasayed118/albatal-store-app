import 'package:al_batal_elite/shared/components/feedback_view.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(FeedbackView view) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: view),
    );

void main() {
  group('FeedbackView empty (UX-039 unified state view)', () {
    testWidgets('renders custom icon, copy and outline CTA', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_harness(FeedbackView(
        type: FeedbackViewType.empty,
        icon: Icons.favorite_border,
        title: 'Nothing saved yet',
        body: 'Browse the catalog to start a wishlist.',
        actionLabel: 'Explore categories',
        onAction: () => tapped = true,
      )));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(
          find.text('Browse the catalog to start a wishlist.'), findsOneWidget);
      expect(find.text('Explore categories'), findsOneWidget);

      await tester.tap(find.text('Explore categories'));
      expect(tapped, isTrue);
    });

    testWidgets('hides the CTA when no onAction is provided', (tester) async {
      await tester.pumpWidget(_harness(const FeedbackView(
        type: FeedbackViewType.empty,
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
      )));

      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      // No l10n 'Return home' default CTA sneaks in without an action.
      expect(find.textContaining('home'), findsNothing);
    });

    testWidgets('error keeps its retry CTA when an action is wired',
        (tester) async {
      await tester.pumpWidget(_harness(FeedbackView(
        type: FeedbackViewType.error,
        onAction: () {},
      )));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
