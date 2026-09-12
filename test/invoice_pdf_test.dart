import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/invoice/invoice_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

AdminOrderItem _item(String name, int qty, int unitMinor) => AdminOrderItem(
      productName: name,
      size: '2m',
      color: 'Emerald',
      quantity: qty,
      unitPrice: Money(unitMinor),
    );

AdminOrder _order({required List<AdminOrderItem> items}) => AdminOrder(
      id: 'ORD-INV-1',
      status: AdminOrderStatus.paid,
      total: const Money(360000),
      placedAt: DateTime.utc(2026, 9, 12),
      customerName: 'Nour Hassan',
      itemCount: items.fold<int>(0, (v, i) => v + i.quantity),
      items: items,
    );

void main() {
  final builder = const InvoicePdfBuilder();

  group('InvoicePdfBuilder (§16)', () {
    test('emits a non-empty PDF document', () async {
      final bytes = await builder.build(_order(items: [
        _item('Royal Emerald Silk', 2, 180000),
      ]));
      expect(bytes, isNotEmpty);
      // PDF magic header.
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    });

    test('rejects an order without line items', () async {
      expect(
        () => builder.build(_order(items: const [])),
        throwsArgumentError,
      );
    });

    test('multi-line invoices produce larger documents', () async {
      final small = await builder.build(_order(items: [
        _item('Silk', 1, 120000),
      ]));
      final large = await builder.build(_order(items: [
        _item('Silk', 1, 120000),
        _item('Wool', 1, 90000),
        _item('Linen', 1, 80000),
      ]));
      expect(large.length, greaterThan(small.length));
    });
  });
}
