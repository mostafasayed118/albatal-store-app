import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/data/admin_mappers.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminOrderStatus.fromName', () {
    test('parses valid DB status names', () {
      expect(AdminOrderStatus.fromName('placed'), AdminOrderStatus.placed);
      expect(AdminOrderStatus.fromName('processing'),
          AdminOrderStatus.processing);
    });

    test('maps null and unknown values to unknown without throwing', () {
      expect(AdminOrderStatus.fromName(null), AdminOrderStatus.unknown);
      expect(AdminOrderStatus.fromName('bogus'), AdminOrderStatus.unknown);
      expect(AdminOrderStatus.fromName(''), AdminOrderStatus.unknown);
    });
  });

  group('AdminMappers.orderFromRow (queue rows)', () {
    test('maps a full queue row with joined profiles and item count', () {
      final order = AdminMappers.orderFromRow({
        'id': 'abc12345-6789',
        'status': 'paid',
        'total': 125000,
        'placed_at': '2026-08-01T10:30:00Z',
        'payment_method': 'card',
        'profiles': {'full_name': 'Ahmed Hassan'},
        'order_items': [
          {'id': 'i1'},
          {'id': 'i2'},
          {'id': 'i3'},
        ],
      });

      expect(order.id, 'abc12345-6789');
      expect(order.status, AdminOrderStatus.paid);
      expect(order.total, const Money(125000));
      expect(order.customerName, 'Ahmed Hassan');
      expect(order.paymentMethod, 'card');
      expect(order.itemCount, 3);
      expect(order.items, isEmpty);
      expect(order.placedAt, DateTime.parse('2026-08-01T10:30:00Z'));
    });

    test('degrades missing/mistyped fields to safe defaults', () {
      final order = AdminMappers.orderFromRow({
        'id': 'abc',
        'status': 'mystery-status',
        'total': 'not-a-number',
        'profiles': <String, dynamic>{},
      });

      expect(order.status, AdminOrderStatus.unknown);
      expect(order.total, Money.zero);
      expect(order.customerName, isNull);
      expect(order.itemCount, 0);
      expect(order.address, isNull);
      expect(order.shortId, 'abc');
    });

    test('blank customer name becomes null', () {
      final order = AdminMappers.orderFromRow({
        'id': 'x',
        'profiles': {'full_name': '   '},
      });
      expect(order.customerName, isNull);
    });
  });

  group('AdminMappers.orderDetailFromRow', () {
    test('maps joined order_items(*) into typed items', () {
      final order = AdminMappers.orderDetailFromRow({
        'id': 'ord1',
        'status': 'placed',
        'total': 99000,
        'order_items': [
          {
            'product_name': 'Royal Emerald Silk',
            'size': '2m',
            'color': 'Emerald',
            'quantity': 2,
            'unit_price': 49500,
          },
          {
            'quantity': 1,
          },
        ],
      });

      expect(order.items.length, 2);
      expect(order.itemCount, 2);
      expect(order.items[0].productName, 'Royal Emerald Silk');
      expect(order.items[0].size, '2m');
      expect(order.items[0].color, 'Emerald');
      expect(order.items[0].quantity, 2);
      expect(order.items[0].unitPrice, const Money(49500));
      // Defensive defaults for the sparse row.
      expect(order.items[1].productName, 'Unknown');
      expect(order.items[1].unitPrice, Money.zero);
    });

    test('handles order_items not being a list', () {
      final order = AdminMappers.orderDetailFromRow({
        'id': 'ord2',
        'order_items': 'garbage',
      });
      expect(order.items, isEmpty);
      expect(order.itemCount, 0);
    });

    test('maps address_snapshot', () {
      final order = AdminMappers.orderDetailFromRow({
        'id': 'ord3',
        'address_snapshot': {
          'recipient': 'Sara Ali',
          'line': '12 Nile St',
          'city': 'Cairo',
          'country': 'Egypt',
        },
      });
      expect(order.address, isNotNull);
      expect(order.address!.recipient, 'Sara Ali');
      expect(order.address!.singleLine, '12 Nile St, Cairo');
    });

    test('all-empty address snapshot maps to null address', () {
      final order = AdminMappers.orderDetailFromRow({
        'id': 'ord4',
        'address_snapshot': {
          'recipient': '',
          'line': '',
          'city': '',
        },
      });
      expect(order.address, isNull);
    });
  });

  group('AdminMappers.lowStockVariantFromRow', () {
    test('maps a valid RPC row', () {
      final variant = AdminMappers.lowStockVariantFromRow({
        'id': 'v-1',
        'product_name': 'Egyptian Cotton',
        'variant_size': '1m',
        'variant_color': 'Natural',
        'current_stock': 2,
      });

      expect(variant, isNotNull);
      expect(variant!.variantId, 'v-1');
      expect(variant.productName, 'Egyptian Cotton');
      expect(variant.variantLabel, '1m / Natural');
      expect(variant.stock, 2);
    });

    test('returns null when the variant id is missing', () {
      expect(AdminMappers.lowStockVariantFromRow({'product_name': 'x'}),
          isNull);
    });

    test('list mapping skips non-map and id-less rows', () {
      final variants = AdminMappers.lowStockVariantsFromRows([
        {
          'id': 'v-1',
          'product_name': 'A',
          'current_stock': 1,
        },
        'not-a-map',
        {'product_name': 'no-id'},
      ]);

      expect(variants.length, 1);
      expect(variants[0].variantId, 'v-1');
    });
  });

  group('AdminOrder status guards', () {
    AdminOrder orderWith(AdminOrderStatus status) => AdminOrder(
          id: 'id',
          status: status,
          total: Money.zero,
          placedAt: DateTime(2026),
        );

    test('paid and placed can be confirmed', () {
      expect(orderWith(AdminOrderStatus.paid).canConfirm, isTrue);
      expect(orderWith(AdminOrderStatus.placed).canConfirm, isTrue);
      expect(orderWith(AdminOrderStatus.shipped).canConfirm, isFalse);
    });

    test('only processing can ship', () {
      expect(orderWith(AdminOrderStatus.processing).canShip, isTrue);
      expect(orderWith(AdminOrderStatus.paid).canShip, isFalse);
    });

    test('only shipped can be delivered', () {
      expect(orderWith(AdminOrderStatus.shipped).canDeliver, isTrue);
      expect(orderWith(AdminOrderStatus.processing).canDeliver, isFalse);
    });

    test('placed, paid, and processing can be cancelled; terminal cannot',
        () {
      expect(orderWith(AdminOrderStatus.placed).canCancel, isTrue);
      expect(orderWith(AdminOrderStatus.paid).canCancel, isTrue);
      expect(orderWith(AdminOrderStatus.processing).canCancel, isTrue);
      expect(orderWith(AdminOrderStatus.delivered).canCancel, isFalse);
      expect(orderWith(AdminOrderStatus.cancelled).canCancel, isFalse);
    });
  });
}
