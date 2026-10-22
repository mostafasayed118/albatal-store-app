import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_wholesale_price_entry.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_catalog_port.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_wholesale_prices_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_wholesale_prices_cubit.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_wholesale_prices_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPricesRepository extends Mock implements AdminWholesalePricesPort {}

class _MockCatalogRepository extends Mock implements AdminCatalogPort {}

AdminProduct _product(String id, String name) => AdminProduct(
      id: id,
      name: name,
      slug: 'slug-$id',
      categoryId: 'cat',
      categoryName: 'Fabrics',
      basePrice: const Money(20000),
      isActive: true,
    );

Widget _harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  late _MockPricesRepository repository;
  late _MockCatalogRepository catalog;

  setUp(() {
    repository = _MockPricesRepository();
    catalog = _MockCatalogRepository();
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([
              AdminWholesalePriceEntry(
                  productId: 'p1', productName: 'Silk', priceMinor: 15000),
            ]));
    when(() => catalog.getAllProducts())
        .thenAnswer((_) async => Success([_product('p1', 'Silk')]));
  });

  testWidgets('page builds and loads its cubit from the injected repositories',
      (tester) async {
    await tester.pumpWidget(_harness(AdminWholesalePricesPage(
      repository: repository,
      catalogRepository: catalog,
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Wholesale prices'), findsOneWidget);
    expect(find.text('Silk'), findsOneWidget);
    expect(find.text('EGP 150.00'), findsOneWidget);
    verify(() => repository.fetchWholesalePrices()).called(1);
    verify(() => catalog.getAllProducts()).called(1);
  });

  testWidgets('page accepts a prebuilt cubit and still triggers its load',
      (tester) async {
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);

    await tester.pumpWidget(_harness(AdminWholesalePricesPage(cubit: cubit)));
    await tester.pump();
    await tester.pump();

    expect(cubit.state.status, AdminWholesalePricesStatus.ready);
    expect(find.text('Silk'), findsOneWidget);
  });
}
