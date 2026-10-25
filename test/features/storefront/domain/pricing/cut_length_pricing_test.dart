import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/pricing/cut_length_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

Product _fabric({double? minCut = 1.0}) => Product(
      id: 'p1',
      name: 'Silk Roll',
      category: 'Silk',
      price: const Money(12000),
      imageColor: 0xFF064E3B,
      sellByLength: true,
      minCutMeters: minCut,
    );

void main() {
  group('tier ladder (kWholesaleTiers)', () {
    test('no tier below the first threshold', () {
      expect(tierDiscountPercent(0.5), 0);
      expect(tierDiscountPercent(9.5), 0);
    });

    test('5% at 10 m, 10% at 25 m, threshold boundaries inclusive', () {
      expect(tierDiscountPercent(10.0), 5);
      expect(tierDiscountPercent(24.5), 5);
      expect(tierDiscountPercent(25.0), 10);
      expect(tierDiscountPercent(50.0), 10);
    });
  });

  group('tiered per-meter Money math', () {
    test('no tier returns the base price untouched', () {
      expect(tieredPerMeterPrice(const Money(12000), 5), const Money(12000));
    });

    test('5% tier truncates in minor units, never rounding up', () {
      expect(tieredPerMeterPrice(const Money(12000), 10), const Money(11400));
      // 12001 * 95 / 100 = 11400.95 -> truncates to 11400.
      expect(tieredPerMeterPrice(const Money(12001), 10), const Money(11400));
    });

    test('10% tier', () {
      expect(tieredPerMeterPrice(const Money(12000), 25), const Money(10800));
    });
  });

  group('metered line total', () {
    test('price x meters in minor units on the 0.5 m grid', () {
      expect(meteredLineTotalWithTier(const Money(12000), 2.5, 0),
          const Money(30000));
      expect(meteredLineTotalWithTier(const Money(12000), 0.5, 0),
          const Money(6000));
    });

    test('quantity multiplies the metered cut', () {
      expect(meteredLineTotalWithTier(const Money(12000), 2, 0, quantity: 3),
          const Money(72000));
    });

    test('applies a tier once at the final line total', () {
      expect(
        meteredLineTotalWithTier(const Money(39950), 2.5, 5),
        const Money(94881),
      );
    });

    test('quantity is applied before final rounding', () {
      expect(
        meteredLineTotalWithTier(const Money(1), 0.5, 5, quantity: 2),
        const Money(1),
      );
    });

    test('a fractional major-unit total renders with its piasters', () {
      // 39950 minor/m (399.50 EGP/m) x 2.5 m = 99875, i.e. 998.75 EGP.
      // Truncating this to whole pounds would display less than the
      // line_total the checkout payload submits for the same line.
      final total = meteredLineTotalWithTier(const Money(39950), 2.5, 0);
      expect(total, const Money(99875));
      expect(total.format(), '998.75 EGP');
    });
  });

  group('CartItemPricing extension', () {
    test('cutMeters parses the length contract for sell-by-length', () {
      final item =
          CartItem(product: _fabric(), color: 'Emerald', length: '12.5');
      expect(item.cutMeters, 12.5);
    });

    test('cutMeters is null for fixed-size products', () {
      const item = CartItem(
          product: Product(
              id: 'p2',
              name: 'Fixed',
              category: 'Silk',
              price: Money(12000),
              imageColor: 0xFF064E3B),
          color: 'Emerald',
          length: '2m');
      expect(item.cutMeters, isNull);
      expect(item.effectiveLineTotal, const Money(12000));
    });

    test('tiered effective line total for a wholesale cut', () {
      final item =
          CartItem(product: _fabric(), color: 'Emerald', length: '12.5');
      // 12.5 m -> 5% tier -> 11400 * 12.5 = 142500.
      expect(item.effectiveLineTotal, const Money(142500));
      expect(item.effectivePerMeterPrice, const Money(11400));
    });

    test('sample lines price at zero client-side', () {
      final item = CartItem(
          product: _fabric(), color: 'Emerald', length: 'sample', sample: true);
      expect(item.sample, isTrue);
      expect(item.effectiveLineTotal, Money.zero);
    });

    test('sample flag distinguishes the cart key from a regular line', () {
      final regular =
          CartItem(product: _fabric(), color: 'Emerald', length: '2.5');
      final sample = CartItem(
          product: _fabric(), color: 'Emerald', length: 'sample', sample: true);
      expect(regular.key, isNot(sample.key));
      expect(sample, isNot(regular));
    });
  });

  group('wholesale list-price parity (078)', () {
    test('effectiveBasePrice falls back to the catalog price', () {
      expect(_fabric().effectiveBasePrice, const Money(12000));
      expect(_fabric().withWholesalePrice(const Money(8000)).effectiveBasePrice,
          const Money(8000));
    });

    test('withWholesalePrice copies without touching the catalog price', () {
      final base = _fabric();
      final listed = base.withWholesalePrice(const Money(8000));
      expect(listed.price, const Money(12000));
      expect(listed.wholesalePrice, const Money(8000));
      expect(listed.id, base.id);
      expect(listed.stock, base.stock);
      // null clears the list price (sign-out strip path).
      expect(listed.withWholesalePrice(null).wholesalePrice, isNull);
    });

    test('metered estimate prices off the list price + ladder (server T4)', () {
      // Server proof T4 (078 staging): list 8000/m, 12.5 m -> 5 % ladder
      // stacks on the LIST base -> 8000*95/100 = 7600/m, 7600*12.5 = 95000.
      final item = CartItem(
        product: _fabric().withWholesalePrice(const Money(8000)),
        color: 'Emerald',
        length: '12.5',
      );
      expect(item.effectivePerMeterPrice, const Money(7600));
      expect(item.effectiveLineTotal, const Money(95000));
    });

    test('fixed-size lines price at the list price for wholesale viewers', () {
      final item = CartItem(
        product: _fabric().withWholesalePrice(const Money(8000)),
        color: 'Emerald',
        length: '2m',
        quantity: 2,
      );
      expect(item.effectiveLineTotal, const Money(16000));
      // The core lineTotal keeps the catalog-price contract.
      expect(item.lineTotal, const Money(24000));
    });

    test('absence of a list row keeps the legacy base-price math', () {
      final item = CartItem(
        product: _fabric().withWholesalePrice(null),
        color: 'Emerald',
        length: '12.5',
      );
      expect(item.effectivePerMeterPrice, const Money(11400));
      expect(item.effectiveLineTotal, const Money(142500));
    });
  });
}
