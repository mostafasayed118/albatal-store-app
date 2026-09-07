import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/catalog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p(String id,
        {required double rating, Money? oldPrice, String category = 'Silk'}) =>
    Product(
      id: id,
      name: 'Product $id',
      category: category,
      price: Money.egp(500),
      oldPrice: oldPrice,
      imageColor: 0xFF176B57,
      rating: rating,
      reviewCount: 10,
    );

void main() {
  group('CatalogState.featuredProducts — hero carousel picks', () {
    test('discounted products lead, best-rated first within each tier', () {
      // Three products → no truncation, so intra-tier order is visible:
      // the discounted item leads; full-price items follow by rating.
      final state = CatalogState(
        allProducts: [
          _p('full-mid', rating: 4.5),
          _p('disc-low', rating: 4.1, oldPrice: Money.egp(600)),
          _p('full-low', rating: 4.9),
        ],
      );

      expect(state.featuredProducts.map((p) => p.id).toList(),
          ['disc-low', 'full-low', 'full-mid']);
    });

    test('a discounted product outranks better-rated full-price ones', () {
      final state = CatalogState(
        allProducts: [
          _p('disc', rating: 4.1, oldPrice: Money.egp(600)),
          _p('full-star', rating: 4.9),
        ],
      );
      expect(state.featuredProducts.map((p) => p.id).toList(),
          ['disc', 'full-star']);
    });

    test('capped at three — a fourth dot never appears', () {
      final state = CatalogState(
        allProducts: List.generate(6, (i) => _p('p-$i', rating: 3.0 + i * 0.1)),
      );
      expect(state.featuredProducts, hasLength(3));
    });

    test('memoized: repeat reads return the identical list', () {
      final state = CatalogState(
        allProducts:
            List.generate(20, (i) => _p('p-$i', rating: 3.0 + i * 0.05)),
      );
      expect(identical(state.featuredProducts, state.featuredProducts), isTrue);
    });

    test('empty catalog → empty picks (hero falls back to promo slide)', () {
      expect(CatalogState().featuredProducts, isEmpty);
    });
  });
}
