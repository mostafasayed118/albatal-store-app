import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/storefront/domain/fit/fit_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recommendedMeters', () {
    test('reference body on reference width: trousers = 1.5 m', () {
      expect(recommendedMeters(FitGarment.trousers), 1.5);
    });

    test('tall body scales up within 1.15×', () {
      // 210 cm: scale = 1.2 but clamped to 1.15 → 3.5 * 1.15 = 4.025 → snap up = 4.5
      expect(recommendedMeters(FitGarment.thobe, heightCm: 210), 4.5);
    });

    test('short body scales down within 0.9×', () {
      // 150 cm: scale = 0.857 but clamped to 0.9 → 3.5 * 0.9 = 3.15 → snap up = 3.5
      expect(recommendedMeters(FitGarment.thobe, heightCm: 150), 3.5);
    });

    test('narrow roll adds the pad', () {
      // 2.0 + 0.5 pad = 2.5 → snap up = 2.5
      expect(
          recommendedMeters(FitGarment.shirt, widthCm: 120), 2.5);
    });

    test('standard or wider width adds no pad', () {
      expect(recommendedMeters(FitGarment.shirt, widthCm: 150), 2.0);
      expect(recommendedMeters(FitGarment.shirt, widthCm: null), 2.0);
      expect(
          recommendedMeters(FitGarment.shirt, widthCm: 200), 2.0);
    });

    test('result snaps up (never down)', () {
      // thobe 3.5 at ref height = 3.5 exactly (already on grid)
      expect(recommendedMeters(FitGarment.thobe), 3.5);
      // shirt 2.0 at ref height = 2.0 exactly
      expect(recommendedMeters(FitGarment.shirt), 2.0);
    });

    test('height clamp bounds the result', () {
      // Below the floor still yields the 0.9 scaled value, never the raw input
      final below = recommendedMeters(FitGarment.shirt, heightCm: 100);
      expect(below, greaterThan(0));
      expect(below, lessThanOrEqualTo(2.0));
    });
  });

  group('isNarrowRoll', () {
    test('true below reference', () =>
        expect(isNarrowRoll(120), isTrue));
    test('false at reference', () =>
        expect(isNarrowRoll(150), isFalse));
    test('false above reference', () =>
        expect(isNarrowRoll(200), isFalse));
    test('null is not narrow', () =>
        expect(isNarrowRoll(null), isFalse));
  });

  group('nearestFixedSize', () {
    test('at-or-above picks the smallest qualifying size', () {
      expect(nearestFixedSize(['1m', '2m', '5m'], 1.5), '2m');
    });

    test('exact match returns itself', () {
      expect(nearestFixedSize(['1m', '2m', '5m'], 2.0), '2m');
    });

    test('above all returns the largest', () {
      expect(nearestFixedSize(['1m', '2m', '5m'], 6.0), '5m');
    });

    test('empty sizes returns null', () {
      expect(nearestFixedSize([], 1.5), isNull);
    });

    test('non-numeric sizes are ignored', () {
      expect(nearestFixedSize(['one', 'M'], 0.5), isNull);
    });
  });

  group('fitApplyLength', () {
    test('sell-by-length returns the meters string', () {
       final p = const Product(
         id: 'fabric-01',
         name: 'Cut Silk',
         category: 'Silk',
         price: Money(12000),
         imageColor: 0xFF064E3B,
         sellByLength: true,
         minCutMeters: 1.0,
       );
      expect(fitApplyLength(p, 12.5), '12.5');
    });

    test('fixed-size returns the nearest size', () {
       final p = const Product(
         id: 'fixed-01',
         name: 'Silk',
        category: 'Silk',
         price: Money(129000),
        imageColor: 0xFF176B57,
        sizes: ['1m', '2m', '5m'],
      );
      expect(fitApplyLength(p, 1.5), '2m');
    });
  });
}
