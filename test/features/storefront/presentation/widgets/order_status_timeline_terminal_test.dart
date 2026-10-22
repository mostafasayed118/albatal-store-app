import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_status_timeline.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The terminal (no progress track) states of the timeline. `cancelled` is
/// already covered elsewhere — `refunded` and `expired` share the same
/// terminal row and must degrade the same way.
Widget _harness(OrderStatus status) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => OrderStatusTimeline(
            status: status,
            scheme: Theme.of(context).colorScheme,
            placedAt: DateTime(2026, 9, 4, 9),
          ),
        ),
      ),
    );

void main() {
  testWidgets('refunded renders the single cancelled terminal row',
      (tester) async {
    await tester.pumpWidget(_harness(OrderStatus.refunded));
    await tester.pump();

    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('expired renders the single cancelled terminal row',
      (tester) async {
    await tester.pumpWidget(_harness(OrderStatus.expired));
    await tester.pump();

    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
