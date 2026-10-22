import 'package:al_batal_elite/features/storefront/presentation/widgets/pricing_tier_table.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(double meters) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PricingTierTable(meters: meters)),
    );

void main() {
  testWidgets('renders the ladder ascending with the 5% tier active at 12m',
      (tester) async {
    await tester.pumpWidget(_harness(12));

    expect(find.text('Wholesale pricing'), findsOneWidget);
    expect(find.text('10+ m — 5% off'), findsOneWidget);
    expect(find.text('25+ m — 10% off'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    final first = tester.getTopLeft(find.text('10+ m — 5% off')).dy;
    final second = tester.getTopLeft(find.text('25+ m — 10% off')).dy;
    expect(first, lessThan(second));

    final active = tester.widget<Text>(find.text('10+ m — 5% off'));
    final inactive = tester.widget<Text>(find.text('25+ m — 10% off'));
    expect(active.style?.fontWeight, FontWeight.bold);
    expect(inactive.style?.fontWeight, FontWeight.normal);
  });

  testWidgets('highlights the 10% tier at 30m', (tester) async {
    await tester.pumpWidget(_harness(30));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final active = tester.widget<Text>(find.text('25+ m — 10% off'));
    final inactive = tester.widget<Text>(find.text('10+ m — 5% off'));
    expect(active.style?.fontWeight, FontWeight.bold);
    expect(inactive.style?.fontWeight, FontWeight.normal);
  });

  testWidgets('no tier below the first threshold', (tester) async {
    await tester.pumpWidget(_harness(3));

    expect(find.text('10+ m — 5% off'), findsOneWidget);
    expect(find.text('25+ m — 10% off'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });
}
