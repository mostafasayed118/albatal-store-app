import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_customer.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_order.dart';
import 'package:al_batal_elite/features/admin/domain/entities/admin_wholesale_price_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Remaining value-object coverage: the getters/`props`/`copyWith` lines the
/// mapper and cubit tests never touch because they only read individual
/// fields.
void main() {
  test('AdminOrderStatus.dbValue serializes the enum name', () {
    expect(AdminOrderStatus.processing.dbValue, 'processing');
    expect(AdminOrderStatus.unknown.dbValue, 'unknown');
  });

  test('AdminOrderItem equality covers every rendered field', () {
    const item = AdminOrderItem(
      productName: 'Emerald Silk',
      size: 'M',
      color: 'Emerald',
      quantity: 2,
      unitPrice: Money(12000),
    );
    const same = AdminOrderItem(
      productName: 'Emerald Silk',
      size: 'M',
      color: 'Emerald',
      quantity: 2,
      unitPrice: Money(12000),
    );

    expect(item, same);
    expect(item.props, hasLength(5));
    expect(
      item ==
          const AdminOrderItem(
            productName: 'Royal Velvet',
            size: 'M',
            color: 'Emerald',
            quantity: 2,
            unitPrice: Money(12000),
          ),
      isFalse,
    );
  });

  test('AdminOrder.copyWith can set the customer tier', () {
    final order = AdminOrder(
      id: 'o1',
      status: AdminOrderStatus.paid,
      total: const Money(12000),
      placedAt: DateTime.utc(2026, 9, 16),
      customerName: 'Layla',
      customerId: 'profile-1',
      customerTier: 'standard',
    );

    final updated = order.copyWith(customerTier: 'premium');
    expect(updated.customerTier, 'premium');
    expect(updated.customerName, 'Layla');
    expect(updated.customerId, 'profile-1');

    final untouched = order.copyWith();
    expect(untouched.customerTier, 'standard');
    expect(untouched, order);
  });

  test('AdminOrderAddress equality covers country and line rendering', () {
    const address = AdminOrderAddress(
      recipient: 'Layla',
      line: '12 Nile Street',
      city: 'Cairo',
      country: 'Egypt',
    );
    const same = AdminOrderAddress(
      recipient: 'Layla',
      line: '12 Nile Street',
      city: 'Cairo',
      country: 'Egypt',
    );

    expect(address, same);
    expect(address.props, ['Layla', '12 Nile Street', 'Cairo', 'Egypt']);
    expect(address.singleLine, '12 Nile Street, Cairo');
  });

  test('AdminWholesalePriceEntry equality covers the updated instant', () {
    final at = DateTime.utc(2026, 9, 16);
    final entry = AdminWholesalePriceEntry(
      productId: 'p1',
      productName: 'Emerald Silk',
      priceMinor: 90000,
      updatedAt: at,
    );
    final same = AdminWholesalePriceEntry(
      productId: 'p1',
      productName: 'Emerald Silk',
      priceMinor: 90000,
      updatedAt: at,
    );

    expect(entry, same);
    expect(entry.props, ['p1', 'Emerald Silk', 90000, at]);
  });

  test('AdminCustomer.copyWith defaults the tier but keeps the identity', () {
    const customer = AdminCustomer(
      id: 'c1',
      name: 'Layla',
      email: 'layla@example.com',
      phone: '0100',
      tier: 'standard',
      isBlocked: false,
    );

    expect(customer.copyWith().tier, 'standard');
    final upgraded = customer.copyWith(tier: 'wholesale');
    expect(upgraded.tier, 'wholesale');
    expect(upgraded.name, 'Layla');
    expect(upgraded.contact, 'layla@example.com');
  });
}
