import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/data/admin_mappers.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminOrderStatus.fromName', () {
    test('parses valid DB status names', () {
      expect(AdminOrderStatus.fromName('placed'), AdminOrderStatus.placed);
      expect(
          AdminOrderStatus.fromName('processing'), AdminOrderStatus.processing);
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
      expect(
          AdminMappers.lowStockVariantFromRow({'product_name': 'x'}), isNull);
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

    test('placed, paid, and processing can be cancelled; terminal cannot', () {
      expect(orderWith(AdminOrderStatus.placed).canCancel, isTrue);
      expect(orderWith(AdminOrderStatus.paid).canCancel, isTrue);
      expect(orderWith(AdminOrderStatus.processing).canCancel, isTrue);
      expect(orderWith(AdminOrderStatus.delivered).canCancel, isFalse);
      expect(orderWith(AdminOrderStatus.cancelled).canCancel, isFalse);
    });
  });

  // Regression: migration 043 added `id` to get_low_stock_products.
  // Before it, the deployed RPC returned no variant id, so the mapper
  // skipped every row and the admin Inventory page always showed
  // "All stock levels are healthy" (staging has variants at stock 0..5).
  // These tests pin the client contract: an id-bearing row MUST map.
  group('AdminMappers.lowStockVariantsFromRows (RPC id contract)', () {
    test('keeps a full post-migration-043 RPC row', () {
      final variants = AdminMappers.lowStockVariantsFromRows([
        {
          'id': '8f539023-31aa-481a-a6a1-6ee5ba987fa6',
          'product_name': 'Golden Charmeuse Silk',
          'variant_size': 'M',
          'variant_color': 'Gold',
          'current_stock': 1,
        },
      ]);

      expect(variants, hasLength(1),
          reason:
              'A row shaped like the deployed RPC (with id) must survive mapping');
      expect(variants.single.variantId, '8f539023-31aa-481a-a6a1-6ee5ba987fa6');
      expect(variants.single.productName, 'Golden Charmeuse Silk');
      expect(variants.single.variantLabel, 'M / Gold');
      expect(variants.single.stock, 1);
    });

    test('drops the pre-migration-043 shape (no id) instead of lying', () {
      // The old RPC shape: every row lacks `id`, so mapping must yield
      // nothing — a row without an id cannot be updated from the
      // Inventory page, and keeping it would produce a broken edit flow.
      final variants = AdminMappers.lowStockVariantsFromRows([
        {
          'product_name': 'Egyptian Cotton',
          'variant_size': '1m',
          'variant_color': 'Natural',
          'current_stock': 2,
        },
      ]);

      expect(variants, isEmpty,
          reason:
              'id-less rows are unmappable; an empty result must surface as '
              'a contract break, not as "all stock levels are healthy"');
    });

    test('mixed batch keeps only id-bearing rows', () {
      final variants = AdminMappers.lowStockVariantsFromRows([
        {'product_name': 'legacy row without id', 'current_stock': 3},
        {
          'id': 'v-2',
          'product_name': 'Irish Linen',
          'variant_size': '2m',
          'variant_color': 'White',
          'current_stock': 4,
        },
        'not-a-map',
      ]);

      expect(variants, hasLength(1));
      expect(variants.single.variantId, 'v-2');
    });
  });

  group('AdminMappers.productsFromRows (admin catalog list)', () {
    test('maps a full products row with joined category', () {
      final products = AdminMappers.productsFromRows([
        {
          'id': 'p-1',
          'name': 'Royal Emerald Silk',
          'slug': 'royal-emerald-silk',
          'description': 'Woven in the delta',
          'composition': '100% mulberry silk',
          'category_id': 'c-1',
          'base_price': 1890.0,
          'is_active': true,
          'categories': {'name': 'Silk'},
        },
      ]);

      expect(products, hasLength(1));
      final p = products.single;
      expect(p.id, 'p-1');
      expect(p.name, 'Royal Emerald Silk');
      expect(p.slug, 'royal-emerald-silk');
      expect(p.categoryId, 'c-1');
      expect(p.categoryName, 'Silk');
      expect(p.basePrice, 1890.0);
      expect(p.isActive, isTrue);
      expect(p.statusLabel, 'Active');
      expect(p.description, 'Woven in the delta');
    });

    test('degrades mistyped fields to safe defaults', () {
      final products = AdminMappers.productsFromRows([
        {
          'id': 'p-2',
          'name': 42,
          'base_price': 'not-a-number',
          'is_active': 'yes',
          'categories': 'not-a-map',
        },
      ]);

      final p = products.single;
      expect(p.name, '');
      expect(p.categoryName, '');
      expect(p.basePrice, 0);
      // Inactive is the safe default: a mistyped flag must not hide the
      // row from the manage list.
      expect(p.isActive, isFalse);
      expect(p.statusLabel, 'Inactive');
    });

    test('skips id-less rows', () {
      final products = AdminMappers.productsFromRows([
        {'name': 'no id'},
        'not-a-map',
      ]);
      expect(products, isEmpty);
    });
  });

  group('AdminMappers.categoriesFromRows (admin category list)', () {
    test('maps category rows and skips id-less entries', () {
      final categories = AdminMappers.categoriesFromRows([
        {
          'id': 'c-1',
          'name': 'Silk',
          'is_active': true,
        },
        {'name': 'no id'},
      ]);

      expect(categories, hasLength(1));
      expect(categories.single.id, 'c-1');
      expect(categories.single.name, 'Silk');
      expect(categories.single.isActive, isTrue);
    });
  });
}
