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
    when(() => catalog.getAllProducts())
        .thenAnswer((_) async => Success([_product('p1', 'Silk')]));
  });

  test('load combines the price list with catalog picker candidates', () async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([
              AdminWholesalePriceEntry(
                  productId: 'p1', productName: 'Silk', priceMinor: 15000),
            ]));
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminWholesalePricesStatus.ready);
    expect(cubit.state.entries.single.productId, 'p1');
    expect(cubit.state.entries.single.priceMinor, 15000);
    expect(cubit.state.products.single.name, 'Silk');
  });

  test('price-list load failure surfaces its machine code', () async {
    when(() => repository.fetchWholesalePrices()).thenAnswer((_) async =>
        const Failure(
            AppError('denied', code: kAdminWholesalePricesLoadFailed)));
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminWholesalePricesStatus.error);
    expect(cubit.state.errorCode, kAdminWholesalePricesLoadFailed);
  });

  test('upsert success reloads the list', () async {
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);
    when(() => repository.upsertWholesalePrice(
            productId: any(named: 'productId'),
            priceMinor: any(named: 'priceMinor')))
        .thenAnswer((_) async => const Success(null));
    var calls = 0;
    when(() => repository.fetchWholesalePrices()).thenAnswer((_) async {
      calls++;
      return Success(calls == 1
          ? const <AdminWholesalePriceEntry>[]
          : const [
              AdminWholesalePriceEntry(
                  productId: 'p1', productName: 'Silk', priceMinor: 15000),
            ]);
    });

    await cubit.load();
    await cubit.upsertPrice(productId: 'p1', priceMinor: 15000);

    expect(cubit.state.status, AdminWholesalePricesStatus.ready);
    expect(cubit.state.entries.single.priceMinor, 15000);
    verify(() =>
            repository.upsertWholesalePrice(productId: 'p1', priceMinor: 15000))
        .called(1);
  });

  test('upsert failure keeps its machine code without a reload', () async {
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([]));
    await cubit.load();
    when(() => repository.upsertWholesalePrice(
            productId: any(named: 'productId'),
            priceMinor: any(named: 'priceMinor')))
        .thenAnswer((_) async => const Failure(
            AppError('rejected', code: kAdminWholesalePriceUpsertFailed)));

    await cubit.upsertPrice(productId: 'p1', priceMinor: 15000);

    expect(cubit.state.status, AdminWholesalePricesStatus.error);
    expect(cubit.state.errorCode, kAdminWholesalePriceUpsertFailed);
  });

  test('delete success removes the entry locally without a refetch', () async {
    when(() => repository.fetchWholesalePrices())
        .thenAnswer((_) async => const Success([
              AdminWholesalePriceEntry(
                  productId: 'p1', productName: 'Silk', priceMinor: 15000),
              AdminWholesalePriceEntry(
                  productId: 'p2', productName: 'Linen', priceMinor: 9000),
            ]));
    final cubit = AdminWholesalePricesCubit(
        repository: repository, catalogRepository: catalog);
    addTearDown(cubit.close);
    await cubit.load();
    when(() => repository.deleteWholesalePrice('p1'))
        .thenAnswer((_) async => const Success(null));

    await cubit.deletePrice('p1');

    expect(cubit.state.status, AdminWholesalePricesStatus.ready);
    expect(cubit.state.entries.map((e) => e.productId), ['p2']);
    verify(() => repository.fetchWholesalePrices()).called(1);
  });
}
