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
      expect(meteredLineTotal(const Money(12000), 2.5), const Money(30000));
      expect(meteredLineTotal(const Money(12000), 0.5), const Money(6000));
    });

    test('quantity multiplies the metered cut', () {
      expect(meteredLineTotal(const Money(12000), 2, quantity: 3),
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
      final total = meteredLineTotal(const Money(39950), 2.5);
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
}
