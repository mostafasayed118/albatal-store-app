import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/entities/flash_sale.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/recently_viewed_store.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fetch_related_stub.dart';

const _silk = Product(
  id: 'silk',
  name: 'Silk Charmeuse',
  category: 'Silk',
  price: Money.egp(1290),
  imageColor: 0xFF004D40,
);

final class _OneProductCatalog
    with FetchRelatedFromProducts
    implements CatalogRepository {
  @override
  Future<Result<Product>> fetchProductById(String id) async =>
      const Success(_silk);

  @override
  Future<Result<List<Product>>> fetchProducts() async => const Success([_silk]);

  @override
  Future<Result<List<String>>> fetchCategories() async =>
      const Success(['Silk']);

  @override
  Product? findProductById(String id) => id == _silk.id ? _silk : null;

  @override
  List<String> get defaultCategories => const ['Silk'];

  @override
  Future<Result<List<FlashSale>>> getActiveFlashSales() =>
      Future.value(const Success<List<FlashSale>>([]));
}

final class _MemoryStore implements RecentlyViewedStore {
  final List<Product> entries = [];

  @override
  List<Product> load() => List.of(entries);

  @override
  void record(Product product) {
    entries.removeWhere((e) => e.id == product.id);
    entries.insert(0, product);
  }

  @override
  void clear() => entries.clear();
}

void main() {
  test('ProductDetailsCubit records the loaded product (#3)', () async {
    final store = _MemoryStore();
    final cubit =
        ProductDetailsCubit(_OneProductCatalog(), recentlyViewed: store);
    addTearDown(cubit.close);

    await cubit.loadProduct(_silk.id);

    expect(store.entries.single.id, _silk.id);
    expect(cubit.state.status, DetailsStatus.ready);
  });
}
