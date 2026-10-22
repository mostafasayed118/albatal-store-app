import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/product_details_section.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bare = Product(
  id: 'bare-01',
  name: 'Bare Fabric',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
);

const _full = Product(
  id: 'full-01',
  name: 'Detailed Fabric',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
  composition: '100% Silk',
  origin: 'Italy',
  care: 'Dry clean only',
  widthCm: 150,
  gsm: 220,
);

const _careOnly = Product(
  id: 'care-01',
  name: 'Care Fabric',
  category: 'Silk',
  price: Money.egp(100),
  imageColor: 0xFF000000,
  care: 'Hand wash cold',
);

Widget _harness(Product product) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => SingleChildScrollView(
            child: ProductDetailsSection(
              product: product,
              l: AppLocalizations.of(context)!,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders composition, origin, width, weight, and care rows',
      (tester) async {
    await tester.pumpWidget(_harness(_full));

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('Dry clean only'), findsOneWidget);
    expect(
      find.text('Composition: 100% Silk', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Origin: Italy', findRichText: true), findsOneWidget);
    expect(find.text('Width: 1.5 m', findRichText: true), findsOneWidget);
    expect(find.text('Weight: 220 GSM', findRichText: true), findsOneWidget);
  });

  testWidgets('renders only the care block when dry-cleaning data is absent',
      (tester) async {
    await tester.pumpWidget(_harness(_careOnly));

    expect(find.text('Details'), findsNothing);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('Hand wash cold'), findsOneWidget);
  });

  testWidgets('renders nothing when the product carries no detail fields',
      (tester) async {
    await tester.pumpWidget(_harness(_bare));

    expect(find.text('Details'), findsNothing);
    expect(find.text('Care'), findsNothing);
    expect(find.byType(RichText), findsNothing);
  });
}
