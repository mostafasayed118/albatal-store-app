import 'dart:convert';

import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_secure_store.dart';

const _product = Product(
  id: 'p1',
  name: 'Royal Silk',
  category: 'Silk',
  price: Money(1000),
  imageColor: 0xFF176B57,
);

Product? _lookup(String id) => id == 'p1' ? _product : null;

void main() {
  late SharedPreferences prefs;
  late MemorySecureStore secure;

  Future<LocalStorefrontPersistence> build() async {
    prefs = await SharedPreferences.getInstance();
    secure = MemorySecureStore();
    return LocalStorefrontPersistence(prefs, secureStore: secure);
  }

  group('LocalStorefrontPersistence.readCart', () {
    test('a non-list payload degrades to an empty cart', () async {
      SharedPreferences.setMockInitialValues(
          {'storefront_cart_lines_v1': jsonEncode('not-a-list')});
      final persistence = await build();

      expect(await persistence.readCart(_lookup), isEmpty);
    });

    test('decodes valid lines and skips unusable ones', () async {
      SharedPreferences.setMockInitialValues({
        'storefront_cart_lines_v1': jsonEncode([
          {
            'productId': 'p1',
            'color': 'Emerald',
            'length': '2m',
            'quantity': 5,
            'sample': true,
          },
          {
            'productId': 'missing',
            'color': 'Emerald',
            'length': '2m',
            'quantity': 1,
          },
          {
            'productId': 'p1',
            'color': 7,
            'length': '2m',
            'quantity': 1,
          },
          {
            'productId': 'p1',
            'color': 'Gold',
            'length': 7,
            'quantity': 1,
          },
          {
            'productId': 'p1',
            'color': 'Gold',
            'length': '2m',
            'quantity': 'many',
          },
          {
            'productId': 'p1',
            'color': 'Gold',
            'length': '2m',
            'quantity': 0,
          },
          {
            'productId': 'p1',
            'color': 'Gold',
            'length': '2m',
            'quantity': 200,
          },
        ]),
      });
      final persistence = await build();

      final cart = await persistence.readCart(_lookup);

      expect(cart, hasLength(3));
      expect(cart[0].product.id, 'p1');
      expect(cart[0].color, 'Emerald');
      expect(cart[0].quantity, 5);
      expect(cart[0].sample, isTrue);
      // 0 clamps up to the minimum quantity, 200 clamps down to the max.
      expect(cart[1].quantity, 1);
      expect(cart[1].sample, isFalse);
      expect(cart[2].quantity, 99);
    });

    test('missing key returns an empty cart', () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await build();

      expect(await persistence.readCart(_lookup), isEmpty);
    });
  });

  group('LocalStorefrontPersistence.writeCart', () {
    test('round-trips the line fields including the sample flag', () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await build();
      const items = [
        CartItem(
            product: _product, color: 'Emerald', length: '2m', quantity: 2),
        CartItem(
            product: _product,
            color: 'Gold',
            length: 'sample',
            quantity: 1,
            sample: true),
      ];

      await persistence.writeCart(items);
      final cart = await persistence.readCart(_lookup);

      expect(cart, hasLength(2));
      expect(cart[0].color, 'Emerald');
      expect(cart[0].length, '2m');
      expect(cart[0].quantity, 2);
      expect(cart[1].sample, isTrue);
      expect(cart[1].length, 'sample');
      final raw =
          jsonDecode(prefs.getString('storefront_cart_lines_v1')!) as List;
      expect((raw[1] as Map)['sample'], isTrue);
      expect((raw[0] as Map).containsKey('sample'), isFalse);
    });
  });

  group('LocalStorefrontPersistence.readWishlist', () {
    test('a non-list payload degrades to an empty set', () async {
      SharedPreferences.setMockInitialValues(
          {'storefront_wishlist_ids_v1': jsonEncode('nope')});
      final persistence = await build();

      expect(await persistence.readWishlist(), isEmpty);
    });

    test('keeps only string ids', () async {
      SharedPreferences.setMockInitialValues({
        'storefront_wishlist_ids_v1': jsonEncode(['p1', 7, 'p2', 'p1']),
      });
      final persistence = await build();

      expect(await persistence.readWishlist(), {'p1', 'p2'});
    });

    test('writeWishlist persists sorted ids and reads back', () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await build();

      await persistence.writeWishlist({'p2', 'p1'});

      expect(prefs.getString('storefront_wishlist_ids_v1'), '["p1","p2"]');
      expect(await persistence.readWishlist(), {'p1', 'p2'});
    });
  });

  group('LocalStorefrontPersistence.readOrders', () {
    test('a non-list secured payload degrades to an empty history', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secure = MemorySecureStore({'storefront_orders_v1': jsonEncode('x')});
      final persistence =
          LocalStorefrontPersistence(prefs, secureStore: secure);

      expect(await persistence.readOrders(), isEmpty);
    });

    test('missing secured and legacy keys return an empty history', () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await build();

      expect(await persistence.readOrders(), isEmpty);
    });
  });
}
