import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/order.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/repositories/catalog_repository.dart';
import 'package:al_batal_elite/features/storefront/presentation/cubit/reorder_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _MapCatalog implements CatalogRepository {
  _MapCatalog(this.products);
  final Map<String, Product> products;

  @override
  Product? findProductById(String id) => products[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product(String id, String name, Map<String, int> stock) => Product(
      id: id,
      name: name,
      category: 'Silk',
      price: const Money(12000),
      imageColor: 0xFF064E3B,
      stock: stock,
    );

CartItem _line(String id, String name, String color, String length, int qty) =>
    CartItem(
      product: _product(id, name, const {}),
      color: color,
      length: length,
      quantity: qty,
    );

Order _order(List<CartItem> items) => Order(
      id: 'o1',
      items: items,
      subtotal: const Money(36000),
      shipping: const Money(0),
      total: const Money(36000),
      status: OrderStatus.delivered,
      placedAt: DateTime(2026, 9, 1),
      paymentMethod: 'cod',
    );

void main() {
  late List<String> addedKeys;
  late List<int> addedQty;

  ReorderCubit buildCubit(Map<String, Product> products) {
    addedKeys = [];
    addedQty = [];
    return ReorderCubit(
      catalog: _MapCatalog(products),
      addToCart: (product, {color = 'Emerald', length = '2m', quantity = 1}) {
        addedKeys.add(CartItem(
                product: product,
                color: color,
                length: length,
                quantity: quantity)
            .key);
        addedQty.add(quantity);
      },
    );
  }

  test('re-adds available lines with original color/length/quantity',
      () async {
    final cubit = buildCubit({
      'p1': _product('p1', 'Silk', {'Emerald-2m': 5}),
    });
    await cubit.reorder(_order([_line('p1', 'Silk', 'Emerald', '2m', 3)]));

    expect(cubit.state.status, ReorderStatus.done);
    expect(cubit.state.addedCount, 1);
    expect(cubit.state.skippedNames, isEmpty);
    expect(addedKeys, ['p1-Emerald-2m']);
    expect(addedKeys.single.endsWith('-2m'), isTrue);
  });

  test('skips products missing from the live catalog', () async {
    final cubit = buildCubit({});
    await cubit.reorder(_order([_line('gone', 'Old Silk', 'Ivory', '3m', 2)]));

    expect(cubit.state.addedCount, 0);
    expect(cubit.state.skippedNames, ['Old Silk']);
  });

  test('skips out-of-stock color/length combinations', () async {
    final cubit = buildCubit({
      'p1': _product('p1', 'Silk', {'Ivory-3m': 0}),
    });
    await cubit.reorder(_order([_line('p1', 'Silk', 'Ivory', '3m', 2)]));

    expect(cubit.state.addedCount, 0);
    expect(cubit.state.skippedNames, ['Silk']);
  });

  test('clamps quantity down to available stock', () async {
    final cubit = buildCubit({
      'p1': _product('p1', 'Silk', {'Emerald-2m': 2}),
    });
    await cubit.reorder(_order([_line('p1', 'Silk', 'Emerald', '2m', 9)]));

    expect(cubit.state.addedCount, 1);
    expect(addedKeys.single, 'p1-Emerald-2m');
    expect(addedQty.single, 2);
  });

  test('empty orders are a no-op', () async {
    final cubit = buildCubit({});
    await cubit.reorder(_order([]));
    expect(cubit.state.status, ReorderStatus.idle);
  });

  test('reset returns to idle', () async {
    final cubit = buildCubit({});
    await cubit.reorder(_order([_line('p1', 'Silk', 'Emerald', '2m', 1)]));
    cubit.reset();
    expect(cubit.state.status, ReorderStatus.idle);
  });
}
