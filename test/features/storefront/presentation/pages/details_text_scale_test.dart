import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/related_card.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/local_catalog_repository.dart';
import '../../../../helpers/memory_storefront_persistence.dart';

/// Same provider set as the details page harness (details_page_test.dart),
/// with the page subtree pinned to a fixed 1.4× system text scale.
Widget _harness(String productId) {
  final persistence = MemoryStorefrontPersistence();
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WishlistCubit(persistence)),
        BlocProvider(create: (_) => CartCubit(persistence)),
      ],
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: DetailsPage(
            id: productId, catalogRepository: LocalCatalogRepository()),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'Details page renders name/price block and CTA without overflow at a '
      '360dp phone viewport with 1.4 system font scale', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness('silk-01'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);

    // Name/price block: AppBar title + body title → two occurrences.
    expect(find.text('Royal Emerald Silk'), findsNWidgets(2));
    expect(find.text('1290 EGY'), findsOneWidget);
    // CTA line total still renders at scale.
    expect(find.text('Add to Cart - 1290 EGY'), findsOneWidget);
  });

  testWidgets(
      'RelatedCard renders name and price without overflow at 1.4 scale '
      'in its 140x200 strip slot', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: Scaffold(
          body: Center(
            child: RelatedCard(
              product: Product(
                id: 'silk-02',
                name: 'Desert Gold Silk',
                category: 'Silk',
                price: Money.egp(1340),
                imageColor: 0xFFB57A2A,
              ),
              onTap: _noop,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Desert Gold Silk'), findsOneWidget);
    expect(find.textContaining('EGY'), findsOneWidget);
  });
}

void _noop() {}
