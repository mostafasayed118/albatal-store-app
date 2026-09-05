import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:al_batal_elite/features/storefront/presentation/pages/categories_page.dart';
import 'package:al_batal_elite/features/storefront/presentation/widgets/fabric_weave_painter.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _products = [
  Product(
    id: 'silk-01',
    name: 'Royal Emerald Silk',
    category: 'Silk',
    price: Money.egp(1290),
    imageColor: 0xFF0B7A4D,
  ),
  Product(
    id: 'cotton-01',
    name: 'Airy Cotton',
    category: 'Cotton',
    price: Money.egp(640),
    imageColor: 0xFF7D8B6A,
  ),
  Product(
    id: 'velvet-01',
    name: 'Midnight Velvet',
    category: 'Velvet',
    price: Money.egp(890),
    imageColor: 0xFF6E1423,
  ),
];

class _StubCatalogRepository implements CatalogRepository {
  @override
  Future<Result<List<Product>>> fetchProducts() async =>
      Success(List.of(_products));

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All', 'Silk', 'Cotton', 'Velvet']);

  @override
  Future<Result<Product>> fetchProductById(String id) async {
    for (final p in _products) {
      if (p.id == id) return Success(p);
    }
    return Failure(AppError('not found'));
  }

  @override
  Product? findProductById(String id) => null;

  @override
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async => [];

  @override
  List<String> get defaultCategories => const ['Silk', 'Cotton', 'Velvet'];
}

Widget _harness() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) => CatalogCubit(_StubCatalogRepository())..load(),
      child: const CategoriesPage(),
    ),
  );
}

void main() {
  group('categoryAccent', () {
    test('curated families return their brand tint', () {
      expect(categoryAccent('Velvet'), const Color(0xFF6E1423));
      expect(categoryAccent('Wool'), const Color(0xFF4A5058));
    });

    test('unknown families get a deterministic tint', () {
      expect(categoryAccent('Lurex'), categoryAccent('Lurex'));
    });
  });

  group('CategoriesPage', () {
    testWidgets('shows the browse grid with one card per category',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GridView), findsOneWidget);

      Finder inGrid(String label) => find.descendant(
            of: find.byType(GridView),
            matching: find.text(label),
          );
      // 'All' is dropped; every real category gets a card.
      expect(inGrid('Silk'), findsOneWidget);
      expect(inGrid('Cotton'), findsOneWidget);
      expect(inGrid('Velvet'), findsOneWidget);
      expect(inGrid('All'), findsNothing);
      // Cards carry the tactile weave tile (painted via CustomPaint).
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is FabricWeavePainter,
        ),
        findsWidgets,
      );
    });

    testWidgets('tapping a category card selects it in the catalog',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Silk'),
        ),
      );
      await tester.pump();

      final cubit =
          tester.element(find.byType(CategoriesPage)).read<CatalogCubit>();
      expect(cubit.state.filters.category, 'Silk');
    });
  });
}
