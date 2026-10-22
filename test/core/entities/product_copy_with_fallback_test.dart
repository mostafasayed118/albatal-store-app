import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CartItem.copyWith keeps quantity when only sample changes', () {
    const item = CartItem(
      product: Product(
        id: 'p1',
        name: 'Silk',
        category: 'Fabric',
        price: Money(1000),
        imageColor: 0,
      ),
      color: 'Emerald',
      length: '2m',
      quantity: 3,
    );

    final flips = item.copyWith(sample: true);
    final keeps = item.copyWith(quantity: 5);

    expect(flips.quantity, 3);
    expect(flips.sample, isTrue);
    expect(keeps.quantity, 5);
    expect(keeps.sample, isFalse);
  });
}
