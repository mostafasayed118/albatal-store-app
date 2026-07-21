import 'package:al_batal_elite/features/storefront/presentation/pages/order_success_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('OrderSuccessPage order id display', () {
    testWidgets('displays the real server order id', (tester) async {
      const orderId = 'ord-9f3a-4b2c-real-server-id';
      await tester.pumpWidget(
          _harness(const OrderSuccessPage(orderId: orderId)));
      await tester.pumpAndSettle();

      expect(find.text('#$orderId'), findsOneWidget);
    });

    testWidgets('does NOT show the hardcoded legacy fallback id',
        (tester) async {
      const orderId = 'ord-real-123';
      await tester.pumpWidget(
          _harness(const OrderSuccessPage(orderId: orderId)));
      await tester.pumpAndSettle();

      expect(find.text('#ORD-2023-8472'), findsNothing);
    });

    testWidgets('shows a recoverable error state when orderId is empty',
        (tester) async {
      // The page must never silently fall back to a fake id. An empty
      // id indicates a routing/checkout bug and must be surfaced.
      await tester.pumpWidget(_harness(const OrderSuccessPage(orderId: '')));
      await tester.pumpAndSettle();

      // No fake id rendered.
      expect(find.text('#'), findsNothing);
      expect(find.text('#ORD-2023-8472'), findsNothing);
      // An error indicator is shown instead of the success check.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
