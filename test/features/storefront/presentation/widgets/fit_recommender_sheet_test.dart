import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/fit_recommender_sheet.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/local_catalog_repository.dart';

Product _product(String id, {bool sellByLength = false}) => Product(
      id: id,
      name: id,
      category: 'Silk',
      price: const Money(12000),
      imageColor: 0xFF064E3B,
      sellByLength: sellByLength,
      minCutMeters: 1.0,
    );

Widget _harness(Product product, ProductDetailsCubit cubit) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: Builder(
            builder: (context) => FitRecommenderSheet(
              product: product,
            ),
          ),
        ),
      ),
    );

ProductDetailsCubit _cubit() => ProductDetailsCubit(
      LocalCatalogRepository(),
      recentlyViewed: null,
    );

void main() {
  group('FitRecommenderSheet', () {
    testWidgets('shows garment chips, height stepper, and result',
        (tester) async {
      await tester.pumpWidget(_harness(_product('fabric'), _cubit()));
      await tester.pumpAndSettle();

      expect(find.text('Find my fit'), findsOneWidget);
      expect(find.text('Trousers'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsWidgets);
      expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
      // Result renders via fitYouNeed(metersText), e.g.
      // "You'll need about 3.5 m" — match the meters substring.
      expect(find.textContaining('3.5 m'), findsWidgets);
    });

    testWidgets('tapping a garment chip changes the result',
        (tester) async {
      await tester.pumpWidget(_harness(_product('fabric'), _cubit()));
      await tester.pumpAndSettle();

      expect(find.textContaining('3.5 m'), findsWidgets);

      await tester.tap(find.text('Shirt'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.0 m'), findsWidgets);
    });

    testWidgets('Apply writes into the details cubit', (tester) async {
      // Fixed-size path: thobe 3.5 m snaps to nearest size '5m' via
      // cubit.length (works with no loaded product; setCutLength
      // requires state.product so it is covered by the domain test).
      final cubit = _cubit();
      await tester.pumpWidget(
          _harness(_product('fabric', sellByLength: false), cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use 3.5 m'));
      await tester.pumpAndSettle();

      expect(cubit.state.length, '5m');
    });

    testWidgets('showFitRecommender modal forwards the PDP cubit',
        (tester) async {
      final cubit = _cubit();
      final product = _product('fabric', sellByLength: false);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFitRecommender(context, product),
                child: const Text('open fit'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open fit'));
      await tester.pumpAndSettle();

      // Sheet rendered above the PDP subtree with the cubit visible.
      expect(find.textContaining('3.5 m'), findsWidgets);

      await tester.tap(find.text('Use 3.5 m'));
      await tester.pumpAndSettle();

      expect(cubit.state.length, '5m');
      // Sheet dismissed back to the opener.
      expect(find.text('open fit'), findsOneWidget);
    });
  });
}
