import 'package:al_batal_elite/features/storefront/data/product_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlashSaleCodec.fromRow (audit P3)', () {
    test('maps a full server row', () {
      final sale = FlashSaleCodec.fromRow({
        'id': 'flash-1',
        'product_id': 'p1',
        'discount_pct': 15,
        'starts_at': '2026-08-24T00:00:00Z',
        'ends_at': '2026-08-25T00:00:00Z',
        'is_active': true,
      });

      expect(sale, isNotNull);
      expect(sale!.productId, 'p1');
      expect(sale.discountPct, 15);
      expect(sale.endsAt, DateTime.parse('2026-08-25T00:00:00Z'));
    });

    test('accepts legacy camelCase keys', () {
      final sale = FlashSaleCodec.fromRow({
        'product_id': 'p2',
        'discountPct': 22,
        'endsAt': '2026-08-26T00:00:00Z',
      });

      expect(sale, isNotNull);
      expect(sale!.productId, 'p2');
      expect(sale.discountPct, 22);
      expect(sale.endsAt, DateTime.parse('2026-08-26T00:00:00Z'));
    });

    test('defaults discount to 15 and endsAt to null when absent', () {
      final sale = FlashSaleCodec.fromRow({'product_id': 'p3'});

      expect(sale, isNotNull);
      expect(sale!.discountPct, 15);
      expect(sale.endsAt, isNull);
    });

    test('returns null when product_id is missing or empty', () {
      expect(FlashSaleCodec.fromRow({'discount_pct': 10}), isNull);
      expect(FlashSaleCodec.fromRow({'product_id': '', 'discount_pct': 10}),
          isNull);
    });

    test('never throws on garbage values', () {
      final sale = FlashSaleCodec.fromRow({
        'product_id': 'p4',
        'discount_pct': 'half-off',
        'ends_at': 'not-a-date',
      });

      expect(sale, isNotNull);
      expect(sale!.discountPct, 15);
      expect(sale.endsAt, isNull);
    });
  });
}
