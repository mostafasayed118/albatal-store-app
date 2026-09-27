import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/presentation/catalog_fabric_label.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/filter_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cubit/catalog_cubit_test.dart' show StubCatalogRepository;

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
  ),
];

/// Captured onApply payload (named record mirrors FilterSheet.onApply).
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

/// The sheet body is a lazily-built ListView: below-fold rows are not in
/// the tree until scrolled into view, so drag the list (which builds them)
/// before asserting or tapping. The harness page behind the sheet has no
/// scrollables, so the sheet's ListView is unique.
Future<void> _scrollTo(WidgetTester tester, String label) async {
  final list = find.byType(ListView);
  // Search downward first, then back up (e.g. Reset sits above the fold
  // after scrolling down to the facet rows).
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
  group('FilterSheet — finder facets', () {
    testWidgets('renders weight, width, fabric, availability, rating rows',
        (tester) async {
      await tester.pumpWidget(_harness((_) {}));
      await _openSheet(tester);

      // The sheet scrolls — scroll each row into view (which builds it)
      // before asserting.
      for (final label in [
        'Fabric weight',
        'Fabric width',
        'Fabric',
        'In stock only',
        'Sold by the meter only',
        'Minimum rating',
        'Light',
        'Wide',
        'cotton',
        'silk',
      ]) {
        await _scrollTo(tester, label);
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('weight chip toggles and commits on Apply', (tester) async {
      _ApplyPayload? applied;
      await tester.pumpWidget(_harness((p) => applied = p));
      await _openSheet(tester);

      await _tapVisible(tester, 'Light');
      await _tapVisible(tester, 'Apply Filters');
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.weight, FabricWeight.light);
      // Untouched facets stay inert.
      expect(applied!.width, FabricWidth.any);
      expect(applied!.fabricKeyword, isEmpty);
      expect(applied!.minRating, 0);
    });

    testWidgets('reset clears facet draft before Apply', (tester) async {
      _ApplyPayload? applied;
      await tester.pumpWidget(_harness((p) => applied = p));
      await _openSheet(tester);

      await _tapVisible(tester, 'Heavy');
      await _tapVisible(tester, 'cotton');
      await _tapVisible(tester, 'Reset Filters');
      await _tapVisible(tester, 'Apply Filters');
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.weight, FabricWeight.any);
      expect(applied!.fabricKeyword, isEmpty);
    });
  });

  group('CatalogCubit — finder setters', () {
    blocTest<CatalogCubit, CatalogState>(
      'setFabricWeight updates filters',
      build: () => CatalogCubit(StubCatalogRepository()),
      act: (cubit) => cubit.setFabricWeight(FabricWeight.heavy),
      expect: () => [
        isA<CatalogState>().having(
          (s) => s.filters.weight,
          'weight',
          FabricWeight.heavy,
        ),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'facet setters compose; clearFabricFilters resets only facets',
      build: () => CatalogCubit(StubCatalogRepository()),
      act: (cubit) {
        cubit.setFabricKeyword('silk');
        cubit.setInStockOnly(true);
        cubit.setMinRating(4.0);
        cubit.clearFabricFilters();
      },
      expect: () => [
        isA<CatalogState>(),
        isA<CatalogState>(),
        isA<CatalogState>(),
        isA<CatalogState>(),
      ],
      verify: (cubit) {
        expect(cubit.state.filters.fabricKeyword, isEmpty);
        expect(cubit.state.filters.inStockOnly, isFalse);
        expect(cubit.state.filters.minRating, 0);
        expect(cubit.state.filters.hasActiveFilters, isFalse);
      },
    );

    test('fabric label helpers map bands to localized copy', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(fabricWeightLabel(l, FabricWeight.light), 'Light');
      expect(fabricWidthLabel(l, FabricWidth.wide), 'Wide');
      expect(fabricWeightLabel(l, FabricWeight.any), 'Any');
    });
  });
}
