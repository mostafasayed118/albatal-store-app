import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/metered_price_line.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _metered = Product(
  id: 'meter-01',
  name: 'Metered Silk',
  category: 'Silk',
  price: Money.egp(400),
  imageColor: 0xFF176B57,
  sellByLength: true,
  minCutMeters: 1,
  colors: ['Gold'],
  stock: {'Gold-1m': 5},
);

Widget _harness(DetailsState state, {Product product = _metered}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MeteredPriceLine(product: product, state: state),
      ),
    );

void main() {
  testWidgets('shows price x meters x quantity for a metered cut',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        const DetailsState(
          status: DetailsStatus.ready,
          product: _metered,
          color: 'Gold',
          length: '2.5',
          quantity: 2,
        ),
      ),
    );

    expect(find.text('Estimated total: 2,000 EGP'), findsOneWidget);
  });

  testWidgets('applies the wholesale tier discount at 12m', (tester) async {
    await tester.pumpWidget(
      _harness(
        const DetailsState(
          status: DetailsStatus.ready,
          product: _metered,
          color: 'Gold',
          length: '12',
          quantity: 1,
        ),
      ),
    );

    expect(find.text('Estimated total: 4,560 EGP'), findsOneWidget);
  });

  testWidgets('prices off the negotiated list price when present',
      (tester) async {
    final wholesale = _metered.withWholesalePrice(const Money.egp(300));
    await tester.pumpWidget(
      _harness(
        DetailsState(
          status: DetailsStatus.ready,
          product: wholesale,
          color: 'Gold',
          length: '2.5',
          quantity: 2,
        ),
        product: wholesale,
      ),
    );

    expect(find.text('Estimated total: 1,500 EGP'), findsOneWidget);
  });

  testWidgets('non-numeric length renders nothing', (tester) async {
    await tester.pumpWidget(
      _harness(
        const DetailsState(
          status: DetailsStatus.ready,
          product: _metered,
          color: 'Gold',
          length: 'sample',
          quantity: 1,
        ),
      ),
    );

    expect(find.textContaining('Estimated total'), findsNothing);
  });
}
