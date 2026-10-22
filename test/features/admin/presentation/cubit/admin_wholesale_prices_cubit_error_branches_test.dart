import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_catalog.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_wholesale_price_entry.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_catalog_port.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_wholesale_prices_port.dart';
import 'package:al_batal_elite/features/admin/presentation/cubit/admin_wholesale_prices_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _WholesaleRepository extends Mock implements AdminWholesalePricesPort {}

class _CatalogRepository extends Mock implements AdminCatalogPort {}

AdminProduct _product(String id, String name) => AdminProduct(
      id: id,
      name: name,
      slug: 'slug-$id',
      categoryId: 'cat',
      categoryName: 'Fabrics',
      basePrice: const Money(20000),
      isActive: true,
    );

void main() {
  late _WholesaleRepository repository;
  late _CatalogRepository catalog;

  setUp(() {
    repository = _WholesaleRepository();
    catalog = _CatalogRepository();
    registerFallbackValue(
        const Failure(AppError('fallback', code: 'fallback')));
  });

  test('catalog failure (prices already loaded) surfaces its code', () async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([
              AdminWholesalePriceEntry(
                  productId: 'p1', productName: 'Silk', priceMinor: 15000),
            ]));
    when(() => catalog.getAllProducts()).thenAnswer((_) async => const Failure(
        AppError('catalog denied', code: kAdminProductsLoadFailed)));
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminWholesalePricesStatus.error);
    expect(cubit.state.errorCode, kAdminProductsLoadFailed);
    expect(cubit.state.entries, isEmpty,
        reason: 'a failed load never publishes half the screen');
    expect(cubit.state.products, isEmpty);
  });

  test('delete failure keeps the entry and exposes the delete code', () async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([
              AdminWholesalePriceEntry(
                  productId: 'p1', productName: 'Silk', priceMinor: 15000),
            ]));
    when(() => catalog.getAllProducts())
        .thenAnswer((_) async => Success([_product('p1', 'Silk')]));
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);
    await cubit.load();
    when(() => repository.deleteWholesalePrice('p1')).thenAnswer((_) async =>
        const Failure(AppError('delete rejected',
            code: kAdminWholesalePriceDeleteFailed)));

    await cubit.deletePrice('p1');

    expect(cubit.state.status, AdminWholesalePricesStatus.error);
    expect(cubit.state.errorCode, kAdminWholesalePriceDeleteFailed);
    expect(cubit.state.entries.single.productId, 'p1');
  });
}
