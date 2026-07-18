import 'package:al_batal_elite/features/storefront/data/local_catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/storefront_cubits.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/categories_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('categories page shows category tiles',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => CatalogCubit(LocalCatalogRepository())..load(),
        child: const CategoriesPage(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Fabric Categories'), findsOneWidget);
    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('Cotton'), findsOneWidget);
    expect(find.text('Velvet'), findsOneWidget);
  });

  testWidgets('tapping a category shows filtered product grid in-place',
      (WidgetTester tester) async {
    final catalog = CatalogCubit(LocalCatalogRepository())..load();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => catalog,
        child: const CategoriesPage(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Silk'));
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('categories page shows loading state initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => CatalogCubit(LocalCatalogRepository()),
        child: const CategoriesPage(),
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
  });
}
