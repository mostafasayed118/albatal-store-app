import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/orders_csv_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

AdminOrder _order({
  required String id,
  String customer = 'Nour',
  int items = 2,
}) =>
    AdminOrder(
      id: id,
      status: AdminOrderStatus.placed,
      total: const Money(120000),
      placedAt: DateTime.utc(2026, 9, 12, 10, 30),
      customerName: customer,
      itemCount: items,
    );

void main() {
  group('buildOrdersCsv (§14)', () {
    test('writes a header and one row per order', () {
      final csv = buildOrdersCsv([
        _order(id: 'ORD-1'),
        _order(id: 'ORD-2', customer: 'Karim', items: 5),
      ]);
      final lines = csv.trim().split(RegExp(r'\r?\n'));
      expect(lines.length, 3);
      expect(lines.first, startsWith('order_id,placed_at,status'));
      expect(lines[1], contains('ORD-1'));
      expect(lines[2], contains('Karim'));
    });

    test('quotes cells containing commas', () {
      final csv = buildOrdersCsv([
        _order(id: 'ORD-1', customer: 'Nour, Inc'),
      ]);
      expect(csv, contains('"Nour, Inc"'));
    });

    test('neutralises formula injection', () {
      final csv = buildOrdersCsv([
        _order(id: 'ORD-1', customer: '=HYPERLINK("http://evil")'),
        _order(id: 'ORD-2', customer: '@evil'),
        _order(id: 'ORD-3', customer: '+SUM(A1)'),
      ]);
      // Dangerous leading characters are prefixed with an apostrophe so
      // spreadsheet apps read them as plain text.
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, contains("'@evil"));
      expect(csv, contains("'+SUM(A1)"));
    });

    test('escapes embedded double quotes', () {
      final csv = buildOrdersCsv([
        _order(id: 'ORD-1', customer: 'The "Silk" Co'),
      ]);
      expect(csv, contains('"The ""Silk"" Co"'));
    });

    test('empty list yields just the header', () {
      final csv = buildOrdersCsv(const []);
      expect(csv.trim(), startsWith('order_id,placed_at'));
      expect(csv.trim().split('\r\n').length, 1);
    });
  });
}
