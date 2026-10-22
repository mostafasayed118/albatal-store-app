import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
// Transitive dep of flutter_test; adding it to pubspec.yaml requires human
// approval per AGENTS.md, hence the scoped lint suppression.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';

final class _Repo with FetchRelatedFromProducts implements CatalogRepository {
  int flashCalls = 0;
  bool failSales = false;

  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['All']);

  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Failure(AppError('not found'));

  @override
  Product? findProductById(String id) => null;

  @override
  List<String> get defaultCategories => const ['All'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() async {
    flashCalls++;
    return failSales
        ? const Failure(AppError('sales offline'))
        : const Success<List<FlashSale>>([]);
  }
}

void main() {
  test('attribute setters, carousel, and recent-query deletion emit', () async {
    final cubit = CatalogCubit(_Repo());
    addTearDown(cubit.close);

    cubit.setFabricWidth(FabricWidth.wide);
    expect(cubit.state.filters.width, FabricWidth.wide);

    cubit.setSellByLengthOnly(true);
    expect(cubit.state.filters.sellByLengthOnly, isTrue);

    cubit.setRemnantsOnly(true);
    expect(cubit.state.filters.remnantsOnly, isTrue);

    cubit.carousel(2);
    expect(cubit.state.carouselIndex, 2);

    fakeAsync((a) {
      final debounced = CatalogCubit(_Repo());
      debounced.updateQuery('silk');
      a.elapse(const Duration(milliseconds: 350));
      expect(debounced.state.recentQueries, ['silk']);

      debounced.updateQuery('');
      a.elapse(const Duration(milliseconds: 350));
      expect(debounced.state.filters.query, isEmpty);
      expect(debounced.state.recentQueries, ['silk'],
          reason: 'clearing the query keeps the recorded history');

      debounced.deleteRecentQuery('silk');
      expect(debounced.state.recentQueries, isEmpty);
      debounced.close();
    });
  });

  test('a flash-sale fetch failure is swallowed', () async {
    final repo = _Repo()..failSales = true;
    final cubit = CatalogCubit(repo);
    addTearDown(cubit.close);

    await cubit.loadFlashSales();

    expect(repo.flashCalls, 1);
    expect(cubit.state.status, CatalogStatus.initial);
    expect(cubit.state.flashSales, isEmpty);
  });

  test('the flash poll refreshes every 60 seconds', () {
    fakeAsync((a) {
      final repo = _Repo();
      final cubit = CatalogCubit(repo);
      cubit.loadFlashSales();
      a.flushMicrotasks();
      expect(repo.flashCalls, 1);

      a.elapse(CatalogCubit.flashPollInterval);
      a.flushMicrotasks();
      expect(repo.flashCalls, 2);

      a.elapse(CatalogCubit.flashPollInterval);
      a.flushMicrotasks();
      expect(repo.flashCalls, 3);

      cubit.close();
    });
  });
}
