import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/status_progress.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the four-stage order progress (Stitch parity): Placed → Confirmed →
/// Shipped → Delivered, with pending/paid mapping onto the reached stages.
void main() {
  Widget harness(OrderStatus status) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return StatusProgress(status: status, scheme: scheme);
            },
          ),
        ),
      );

  Future<List<String>> labels(WidgetTester tester) async {
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) {
      final data = t.data ?? '';
      // Strip the leading ●/○ marker, keep the label.
      return data.replaceAll(RegExp(r'^[●○]\s*'), '');
    }).toList();
    return texts;
  }

  testWidgets('renders the four lifecycle stages in order', (tester) async {
    await tester.pumpWidget(harness(OrderStatus.placed));
    await tester.pump();
    expect(
        await labels(tester), ['Placed', 'Processing', 'Shipped', 'Delivered']);
  });

  testWidgets('placed reaches stage 1; processing reaches stage 2',
      (tester) async {
    await tester.pumpWidget(harness(OrderStatus.placed));
    await tester.pump();
    final placed = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(placed.first, startsWith('● '));
    expect(placed[1], startsWith('○ '));

    await tester.pumpWidget(harness(OrderStatus.processing));
    await tester.pump();
    final confirmed = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(confirmed[1], startsWith('● '));
    expect(confirmed[2], startsWith('○ '));
  });

  testWidgets('delivered reaches every stage', (tester) async {
    await tester.pumpWidget(harness(OrderStatus.delivered));
    await tester.pump();
    final all = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    for (final label in all) {
      expect(label, startsWith('● '));
    }
  });

  testWidgets('pending maps to stage 1; paid maps to stage 2 (Confirmed)',
      (tester) async {
    await tester.pumpWidget(harness(OrderStatus.pending));
    await tester.pump();
    var markers = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').substring(0, 1))
        .toList();
    expect(markers, ['●', '○', '○', '○']);

    await tester.pumpWidget(harness(OrderStatus.paid));
    await tester.pump();
    markers = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').substring(0, 1))
        .toList();
    expect(markers, ['●', '●', '○', '○']);
  });

  testWidgets('cancelled shows no reached stage', (tester) async {
    await tester.pumpWidget(harness(OrderStatus.cancelled));
    await tester.pump();
    final markers = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').substring(0, 1))
        .toList();
    expect(markers, everyElement('○'));
  });
}
