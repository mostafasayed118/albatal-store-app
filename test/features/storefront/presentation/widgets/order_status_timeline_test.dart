import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/order_status_timeline.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the order-status timeline (#4): Placed → Confirmed → Shipped →
/// Delivered with a Cancelled terminal state, and graceful degradation
/// when the data has no per-step timestamps (only placedAt exists today).
void main() {
  Widget harness(
    OrderStatus status, {
    DateTime? placedAt,
    DateTime? confirmedAt,
    DateTime? shippedAt,
    DateTime? deliveredAt,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return OrderStatusTimeline(
                status: status,
                scheme: scheme,
                placedAt: placedAt,
                confirmedAt: confirmedAt,
                shippedAt: shippedAt,
                deliveredAt: deliveredAt,
              );
            },
          ),
        ),
      );

  testWidgets('placed-only: stage 1 reached with its timestamp, rest pending',
      (tester) async {
    await tester.pumpWidget(harness(
      OrderStatus.placed,
      placedAt: DateTime(2026, 9, 4, 14, 30),
    ));
    await tester.pump();

    expect(find.text('Placed'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Shipped'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    // The placed step carries the only timestamp the data has.
    expect(find.text('4 Sep 2026, 14:30'), findsOneWidget);
  });

  testWidgets('shipped: first three stages done without any timestamps',
      (tester) async {
    await tester.pumpWidget(harness(OrderStatus.shipped));
    await tester.pump();

    // Shipped itself is reached — same ● semantics as StatusProgress.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    // Degrade gracefully: no per-step data → no timestamp text at all.
    expect(find.textContaining(RegExp(r'\d{1,2}:\d{2}')), findsNothing);
  });

  testWidgets('delivered: every stage reached', (tester) async {
    await tester.pumpWidget(harness(OrderStatus.delivered));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('cancelled: single error terminal row, no progress track',
      (tester) async {
    await tester.pumpWidget(harness(
      OrderStatus.cancelled,
      placedAt: DateTime(2026, 9, 4, 9),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text('Cancelled'), findsOneWidget);
    // No invented timestamps — the backend has no cancellation stamp.
    expect(find.textContaining(RegExp(r'\d{1,2}:\d{2}')), findsNothing);
  });
}
