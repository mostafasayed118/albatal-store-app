import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/search_suggestions_bar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String name) => Product(
      id: name,
      name: name,
      category: 'Silk',
      price: const Money(12000),
      imageColor: 0xFF064E3B,
    );

void main() {
  group('suggestProductNames (§7)', () {
    final products = [
      _product('Royal Emerald Silk'),
      _product('Silk Chiffon Ivory'),
      _product('Wool Blend Charcoal'),
      _product('silk organza'),
    ];

    test('matches case-insensitively', () {
      final names = suggestProductNames(products, 'SILK');
      expect(names, contains('Silk Chiffon Ivory'));
      expect(names, contains('silk organza'));
    });

    test('drops exact matches and ranks earliest match first', () {
      final names = suggestProductNames(products, 'silk');
      expect(names, isNot(contains('silk'))); // exact == query is dropped
      expect(names.first, 'Silk Chiffon Ivory'); // 'Silk' at index 0
    });

    test('no match returns empty', () {
      expect(suggestProductNames(products, 'linen'), isEmpty);
    });

    test('blank query returns empty', () {
      expect(suggestProductNames(products, '  '), isEmpty);
    });

    test('respects the limit', () {
      final many = List.generate(9, (i) => _product('Silk $i'));
      expect(suggestProductNames(many, 'Silk').length, 5);
    });
  });

  group('SearchSuggestionsBar', () {
    testWidgets('renders chips and fires onPick/onClear', (tester) async {
      var picked = '';
      var cleared = false;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchSuggestionsBar(
            label: 'Recent searches',
            terms: const ['silk', 'wool'],
            onPick: (t) => picked = t,
            onClear: () => cleared = true,
          ),
        ),
      ));

      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('silk'), findsOneWidget);

      await tester.tap(find.text('silk'));
      expect(picked, 'silk');

      await tester.tap(find.text('Clear'));
      expect(cleared, isTrue);
    });

    testWidgets('renders nothing for empty terms', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SearchSuggestionsBar(
            label: 'Suggestions',
            terms: const [],
            onPick: (_) {},
          ),
        ),
      ));
      expect(find.text('Suggestions'), findsNothing);
    });
  });
}
