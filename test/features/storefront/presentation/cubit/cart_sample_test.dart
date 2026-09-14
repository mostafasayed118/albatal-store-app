import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/cart_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/cart_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/products_data.dart';

class _InMemoryCartRepository implements CartRepository {
  List<CartItem> lastWritten = const [];

  @override
  Future<Result<List<CartItem>>> readCart(ProductLookup productForId) async =>
      const Success([]);

  @override
  Future<Result<void>> writeCart(List<CartItem> items) async {
    lastWritten = List.of(items);
    return const Success(null);
  }
}

void main() {
  group('CartCubit.addSample (Wave C)', () {
    test('adds a flagged sample line priced at zero', () async {
      final cubit = CartCubit(_InMemoryCartRepository());
      cubit.addSample(products.first, color: 'Emerald');

      expect(cubit.state.items, hasLength(1));
      final item = cubit.state.items.single;
      expect(item.sample, isTrue);
      expect(item.length, 'sample');
      expect(cubit.state.subtotal, Money.zero);
      await cubit.close();
    });

    test('is idempotent per product+color', () async {
      final cubit = CartCubit(_InMemoryCartRepository());
      cubit.addSample(products.first, color: 'Emerald');
      cubit.addSample(products.first, color: 'Emerald');

      expect(cubit.state.items, hasLength(1));
      await cubit.close();
    });

    test('sample line coexists with the regular variant line', () async {
      final cubit = CartCubit(_InMemoryCartRepository());
      cubit.add(products.first, color: 'Emerald', length: '2m', quantity: 1);
      cubit.addSample(products.first, color: 'Emerald');

      expect(cubit.state.items, hasLength(2));
      // Subtotal is the regular line alone; the sample contributes zero.
      expect(cubit.state.subtotal, products.first.price * 1);
      await cubit.close();
    });

    test('sample flag survives the persistence boundary round-trip', () async {
      final repo = _InMemoryCartRepository();
      final cubit = CartCubit(repo);
      cubit.addSample(products.first, color: 'Emerald');
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastWritten.single.sample, isTrue);
      await cubit.close();
    });
  });
}
