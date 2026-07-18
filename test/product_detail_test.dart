import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/product_details_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product', () {
    test('stockFor returns stock for a specific variant', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: 100,
        imageColor: 0xFF000000,
        stock: {
          'Emerald-1m': 10,
          'Emerald-2m': 5,
          'Gold-1m': 0,
        },
      );
      expect(p.stockFor('Emerald', '1m'), 10);
      expect(p.stockFor('Emerald', '2m'), 5);
      expect(p.stockFor('Gold', '1m'), 0);
      expect(p.stockFor('Ivory', '5m'), 0);
    });

    test('inStock returns true when any variant has stock', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: 100,
        imageColor: 0xFF000000,
        stock: {'A-1m': 0, 'B-1m': 5},
      );
      expect(p.inStock, isTrue);
    });

    test('inStock returns false when all variants are out of stock', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: 100,
        imageColor: 0xFF000000,
        stock: {'A-1m': 0, 'B-1m': 0},
      );
      expect(p.inStock, isFalse);
    });

    test('discountPercent calculates correctly', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: 850,
        imageColor: 0xFF000000,
        oldPrice: 1000,
      );
      expect(p.discountPercent, 15);
    });

    test('discountPercent is null when no oldPrice', () {
      const p = Product(
        id: 'test',
        name: 'Test',
        category: 'Silk',
        price: 100,
        imageColor: 0xFF000000,
      );
      expect(p.discountPercent, isNull);
    });
  });

  group('CartItem', () {
    test('key combines product id, color, and length', () {
      const p = Product(
        id: 'silk-01',
        name: 'Silk',
        category: 'Silk',
        price: 100,
        imageColor: 0xFF000000,
      );
      const item = CartItem(product: p, color: 'Emerald', length: '2m');
      expect(item.key, 'silk-01-Emerald-2m');
    });

    test('copyWith preserves all fields', () {
      const p = Product(
        id: 'silk-01',
        name: 'Silk',
        category: 'Silk',
        price: 100,
        imageColor: 0xFF000000,
      );
      const item =
          CartItem(product: p, color: 'Gold', length: '5m', quantity: 3);
      final copy = item.copyWith(quantity: 5);
      expect(copy.product, p);
      expect(copy.color, 'Gold');
      expect(copy.length, '5m');
      expect(copy.quantity, 5);
    });
  });

  group('ProductDetailsCubit', () {
    blocTest<ProductDetailsCubit, DetailsState>(
      'changes color',
      build: () => ProductDetailsCubit(),
      act: (cubit) => cubit.color('Gold'),
      verify: (cubit) => expect(cubit.state.color, 'Gold'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'changes length',
      build: () => ProductDetailsCubit(),
      act: (cubit) => cubit.length('5m'),
      verify: (cubit) => expect(cubit.state.length, '5m'),
    );

    blocTest<ProductDetailsCubit, DetailsState>(
      'changes quantity with clamping',
      build: () => ProductDetailsCubit(),
      act: (cubit) {
        cubit.quantity(0);
        cubit.quantity(100);
        cubit.quantity(5);
      },
      verify: (cubit) => expect(cubit.state.quantity, 5),
    );
  });
}
