import 'package:al_batal_elite/features/storefront/data/local_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/wishlist_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/details_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
      child: DetailsPage(
          id: productId, catalogRepository: LocalCatalogRepository()),
    ),
  );
}

void main() {
  testWidgets('details page shows product name and price',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness('silk-01'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Royal Emerald Silk'), findsOneWidget);
    expect(find.text('1,290 EGP'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
  });

  testWidgets('details page shows wishlist and share buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness('silk-01'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Add to wishlist'), findsOneWidget);
    expect(find.byTooltip('Share product'), findsOneWidget);
  });

  testWidgets('details page shows variant chips after scrolling',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness('silk-01'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(find.text('Color'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Emerald'), findsOneWidget);
    expect(find.text('Length'), findsOneWidget);
  });
}
