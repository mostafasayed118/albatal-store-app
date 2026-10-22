import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/filter_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _products = [
  Product(
    id: 'light-cotton',
    name: 'Light Cotton',
    category: 'Cotton',
    price: Money.egp(200),
    imageColor: 0xFF176B57,
    gsm: 120,
    widthCm: 140,
    composition: 'Egyptian Cotton',
    colors: ['Emerald', 'Gold'],
  ),
  Product(
    id: 'heavy-wool',
    name: 'Heavy Wool',
    category: 'Wool',
    price: Money.egp(900),
    imageColor: 0xFFB57A2A,
    gsm: 350,
    widthCm: 160,
    composition: 'Wool Blend',
    colors: ['Navy'],
  ),
];

typedef _ApplyPayload = ({
  String category,
  String color,
  Money priceMin,
  Money priceMax,
  FabricWeight weight,
  FabricWidth width,
  String fabricKeyword,
  bool inStockOnly,
  bool sellByLengthOnly,
  double minRating,
  bool remnantsOnly,
});

Widget _harness(void Function(_ApplyPayload) onApply) {
  final state = CatalogState(
    status: CatalogStatus.ready,
    allProducts: _products,
    categories: const ['All', 'Cotton', 'Wool'],
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
                onApply: ({
                  required category,
                  required color,
                  required priceMin,
                  required priceMax,
                  required weight,
                  required width,
                  required fabricKeyword,
                  required inStockOnly,
                  required sellByLengthOnly,
                  required minRating,
                  required remnantsOnly,
                }) =>
                    onApply((
                  category: category,
                  color: color,
                  priceMin: priceMin,
                  priceMax: priceMax,
                  weight: weight,
                  width: width,
                  fabricKeyword: fabricKeyword,
                  inStockOnly: inStockOnly,
                  sellByLengthOnly: sellByLengthOnly,
                  minRating: minRating,
                  remnantsOnly: remnantsOnly,
                )),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, String label) async {
  final list = find.byType(ListView);
  for (final dy in [-300.0, 300.0]) {
    for (var i = 0; i < 12; i++) {
      if (find.text(label).evaluate().isNotEmpty) return;
      await tester.drag(list, Offset(0, dy));
      await tester.pumpAndSettle();
    }
  }
}

Future<void> _tapVisible(WidgetTester tester, String label) async {
  await _scrollTo(tester, label);
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('category, width, and availability chips commit on Apply',
      (tester) async {
    _ApplyPayload? applied;
    await tester.pumpWidget(_harness((p) => applied = p));
    await _openSheet(tester);

    await _tapVisible(tester, 'Cotton');
    await _tapVisible(tester, 'Wide');
    await _tapVisible(tester, 'In stock only');
    await _tapVisible(tester, 'Sold by the meter only');
    await _tapVisible(tester, 'Remnants only');
    await _tapVisible(tester, '4+');
    await _tapVisible(tester, 'Apply Filters');
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.category, 'Cotton');
    expect(applied!.width, FabricWidth.wide);
    expect(applied!.inStockOnly, isTrue);
    expect(applied!.sellByLengthOnly, isTrue);
    expect(applied!.remnantsOnly, isTrue);
    expect(applied!.minRating, 4.0);
  });

  testWidgets('the price slider reports a changed range on Apply',
      (tester) async {
    _ApplyPayload? applied;
    await tester.pumpWidget(_harness((p) => applied = p));
    await _openSheet(tester);
    expect(find.byType(FilterSheet), findsOneWidget);

    await _scrollTo(tester, 'Price Range');
    await tester.drag(find.byType(RangeSlider), const Offset(-60, 0));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.priceMin, isA<Money>());
    expect(applied!.priceMax, isA<Money>());
    expect(applied!.priceMax.minorUnits,
        greaterThanOrEqualTo(applied!.priceMin.minorUnits));
  });
}
