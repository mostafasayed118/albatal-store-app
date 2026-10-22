import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/metered_price_line.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/pricing_tier_table.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/quantity_stepper.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/variant_selector.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';

const _fixed = Product(
  id: 'fixed-01',
  name: 'Fixed Silk',
  category: 'Silk',
  price: Money.egp(500),
  imageColor: 0xFF176B57,
  colors: ['Emerald', 'Gold', 'Ivory'],
  sizes: ['1m', '2m', '5m'],
  stock: {'Emerald-1m': 4, 'Gold-2m': 7},
);

const _soldOut = Product(
  id: 'sold-01',
  name: 'Sold Out Silk',
  category: 'Silk',
  price: Money.egp(500),
  imageColor: 0xFF176B57,
  colors: ['Ivory'],
  sizes: ['5m'],
  stock: {'Ivory-5m': 0},
);

const _metered = Product(
  id: 'meter-01',
  name: 'Metered Silk',
  category: 'Silk',
  price: Money.egp(400),
  imageColor: 0xFF176B57,
  sellByLength: true,
  minCutMeters: 1,
  colors: ['Gold', 'Amber'],
  stock: {'Gold-1m': 5},
);

class _Repo with FetchRelatedFromProducts implements CatalogRepository {
  _Repo(this.product);

  final Product product;

  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(<Product>[product]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk']);

  @override
  Future<Result<Product>> fetchProductById(String id) async => id == product.id
      ? Success(product)
      : const Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => id == product.id ? product : null;

  @override
  List<String> get defaultCategories => const ['All', 'Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async =>
      const Success<List<FlashSale>>([]);
}

Widget _harness(Product product) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) =>
            ProductDetailsCubit(_Repo(product))..loadProduct(product.id),
        child: Scaffold(
          body: BlocBuilder<ProductDetailsCubit, DetailsState>(
            builder: (context, state) => state.status == DetailsStatus.ready
                ? SingleChildScrollView(
                    child: VariantSelector(
                      product: state.product!,
                      state: state,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );

ProductDetailsCubit _cubit(WidgetTester tester) =>
    tester.element(find.byType(VariantSelector)).read<ProductDetailsCubit>();

ChoiceChip _chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
    );

Future<void> _pumpReady(WidgetTester tester, Product product) async {
  await tester.pumpWidget(_harness(product));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('fixed sizes render color and length chips with defaults',
      (tester) async {
    await _pumpReady(tester, _fixed);

    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Length'), findsOneWidget);
    expect(_chip(tester, 'Emerald').selected, isTrue);
    expect(_chip(tester, 'Gold').selected, isFalse);
    expect(_chip(tester, '1m').selected, isTrue);
    expect(find.text('Find my fit'), findsOneWidget);
  });

  testWidgets('selecting a color and length updates the details state',
      (tester) async {
    await _pumpReady(tester, _fixed);

    await tester.tap(find.text('Gold'));
    await tester.pump();
    expect(_cubit(tester).state.color, 'Gold');

    await tester.tap(find.text('5m'));
    await tester.pump();
    expect(_cubit(tester).state.length, '5m');
    expect(_chip(tester, '5m').selected, isTrue);
  });

  testWidgets('out-of-stock variant shows the badge and pins quantity to 1',
      (tester) async {
    await _pumpReady(tester, _soldOut);

    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.byType(QuantityStepper), findsOneWidget);

    final add = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.add_circle_outline),
        matching: find.byType(IconButton),
      ),
    );
    final remove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.remove_circle_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(add.onPressed, isNull);
    expect(remove.onPressed, isNull);
  });

  testWidgets('sell-by-length products render the metered controls',
      (tester) async {
    await _pumpReady(tester, _metered);

    expect(find.text('1.0 m'), findsOneWidget);
    expect(
        find.text('Sold by the meter — minimum cut applies.'), findsOneWidget);
    expect(find.byType(MeteredPriceLine), findsOneWidget);
    expect(find.byType(PricingTierTable), findsOneWidget);
    expect(find.text('Wholesale pricing'), findsOneWidget);
    expect(find.text('Find my fit'), findsOneWidget);
  });

  testWidgets('metered plus and minus snap to half-meter steps',
      (tester) async {
    await _pumpReady(tester, _metered);

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pump();
    expect(_cubit(tester).state.length, '1.5');

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pump();
    expect(_cubit(tester).state.length, '1.0');
  });
}
