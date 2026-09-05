import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/color_swatches.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/filter_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _products = [
  Product(
    id: 'silk-emerald',
    name: 'Royal Emerald Silk',
    category: 'Silk',
    price: Money.egp(1290),
    imageColor: 0xFF176B57, // catalogColorName → 'Emerald'
  ),
  Product(
    id: 'silk-amber',
    name: 'Amber Silk',
    category: 'Silk',
    price: Money.egp(1190),
    imageColor: 0xFFB57A2A, // catalogColorName → 'Amber'
  ),
];

Widget _harness() {
  final state = CatalogState(
    status: CatalogStatus.ready,
    allProducts: _products,
  );
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => FilterSheet(
                state: state,
                onApply: (_, __, ___, ____) {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('color filter chips carry fabric swatch dots', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // One dot per color option, mirroring the PDP variant chips.
    expect(find.byType(ColorSwatchDot), findsNWidgets(2));

    for (final name in ['Emerald', 'Amber']) {
      final chip =
          find.ancestor(of: find.text(name), matching: find.byType(ChoiceChip));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.byType(ColorSwatchDot)),
        findsOneWidget,
      );
    }
  });

  testWidgets('selecting a color keeps its dot visible', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Emerald'));
    await tester.pump();

    final chip = find.ancestor(
      of: find.text('Emerald'),
      matching: find.byType(ChoiceChip),
    );
    expect(
      tester.widget<ChoiceChip>(chip).selected,
      isTrue,
      reason: 'tapping a color chip selects it as the filter',
    );
    expect(
      find.descendant(of: chip, matching: find.byType(ColorSwatchDot)),
      findsOneWidget,
    );
  });
}
