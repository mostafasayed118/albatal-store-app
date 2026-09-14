import 'package:al_batal_elite/features/admin/data/admin_mappers.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic aggregation tests for the sales-dashboard mapper (#12).
/// `now` is injected, so the day window is fully controlled.
void main() {
  final now = DateTime(2026, 9, 13, 10, 30);

  Map<String, dynamic> orderRow({
    required String placedAt,
    String status = 'paid',
    int total = 100000,
    List<dynamic>? items,
  }) =>
      {
        'id': 'o1',
        'status': status,
        'total': total,
        'placed_at': placedAt,
        if (items != null) 'order_items': items,
      };

  group('AdminMappers.salesOverviewFromRows', () {
    test('zero-fills exactly one revenue point per day of the window', () {
      final overview = AdminMappers.salesOverviewFromRows(
        [orderRow(placedAt: '2026-09-10T12:00:00Z', total: 50000)],
        days: 14,
        now: now,
      );
      expect(overview.revenueByDay, hasLength(14));
      // Oldest first: 2026-08-31 .. 2026-09-13 (UTC calendar days).
      expect(overview.revenueByDay.first.day, DateTime.utc(2026, 8, 31));
      expect(overview.revenueByDay.last.day, DateTime.utc(2026, 9, 13));
      // Only Sep 10 carries revenue; the rest are zero-filled.
      expect(
        overview.revenueByDay.every((p) => p.day == DateTime.utc(2026, 9, 10)
            ? p.revenueMinor == 50000
            : p.revenueMinor == 0),
        isTrue,
      );
    });

    test('excludes cancelled and refunded orders from revenue and best sellers',
        () {
      final overview = AdminMappers.salesOverviewFromRows(
        [
          orderRow(
              placedAt: '2026-09-12T12:00:00Z',
              status: 'cancelled',
              total: 99999,
              items: [
                {'product_name': 'Silk', 'quantity': 5},
              ]),
          orderRow(
              placedAt: '2026-09-12T13:00:00Z',
              status: 'refunded',
              total: 88888,
              items: [
                {'product_name': 'Velvet', 'quantity': 3},
              ]),
          orderRow(placedAt: '2026-09-12T14:00:00Z', total: 20000, items: [
            {'product_name': 'Silk', 'quantity': 2},
          ]),
        ],
        days: 14,
        now: now,
      );
      expect(
        overview.revenueByDay
            .singleWhere((p) => p.day == DateTime.utc(2026, 9, 12))
            .revenueMinor,
        20000,
      );
      expect(overview.topProducts.single.productName, 'Silk');
      expect(overview.topProducts.single.unitsSold, 2);
      // …but they still appear in the status counts.
      final cancelled = overview.statusCounts
          .singleWhere((c) => c.status == AdminOrderStatus.cancelled);
      expect(cancelled.count, 1);
      final refunded = overview.statusCounts
          .singleWhere((c) => c.status == AdminOrderStatus.refunded);
      expect(refunded.count, 1);
    });

    test('skips malformed rows and malformed line items defensively', () {
      final overview = AdminMappers.salesOverviewFromRows(
        [
          <String, dynamic>{}, // no placed_at — skipped entirely
          'not-a-map', // wrong row type — skipped
          orderRow(placedAt: '2026-09-12T12:00:00Z', total: 10000, items: [
            'not-a-map', // non-map item — ignored
            {'product_name': 'Silk'}, // missing quantity — 0, ignored
            {'product_name': 'Silk', 'quantity': -3}, // negative — ignored
            {'product_name': 'Silk', 'quantity': 2},
            {'quantity': 4}, // missing name — falls back to Unknown
          ]),
        ],
        days: 14,
        now: now,
      );
      expect(overview.topProducts, hasLength(2));
      expect(overview.topProducts.first.productName, 'Unknown');
      expect(overview.topProducts.first.unitsSold, 4);
      expect(overview.topProducts.last.productName, 'Silk');
      expect(overview.topProducts.last.unitsSold, 2);
    });

    test('caps best sellers at five and orders by units sold', () {
      final overview = AdminMappers.salesOverviewFromRows(
        [
          for (var p = 0; p < 7; p++)
            orderRow(placedAt: '2026-09-12T12:00:00Z', total: 1000, items: [
              {'product_name': 'P$p', 'quantity': p + 1},
            ]),
        ],
        days: 14,
        now: now,
      );
      expect(overview.topProducts, hasLength(5));
      expect(
        overview.topProducts.map((t) => t.productName),
        ['P6', 'P5', 'P4', 'P3', 'P2'],
      );
    });
  });
}
