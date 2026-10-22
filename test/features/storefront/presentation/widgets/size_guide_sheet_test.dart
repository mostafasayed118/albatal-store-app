import 'package:al_batal_elite/features/storefront/presentation/widgets/size_guide_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSizeGuide(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders the width / length / best-for table', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Size Guide'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Length'), findsOneWidget);
    expect(find.text('Width'), findsOneWidget);
    expect(find.text('Best For'), findsOneWidget);
    expect(find.text('1m'), findsOneWidget);
    expect(find.text('2m'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('110 cm'), findsNWidgets(3));
    expect(find.text('Small projects, swatches'), findsOneWidget);
    expect(find.text('Garments, dresses'), findsOneWidget);
    expect(find.text('Full suits, upholstery'), findsOneWidget);
  });

  testWidgets('Got it dismisses the sheet', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Size Guide'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
