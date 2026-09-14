import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/data/checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'checkout_service_test.dart'
    show MockSupabaseClient, FakePostgrestFilterBuilder;

Product _cutFabric() => const Product(
      id: 'fabric-01',
      name: 'Cut Silk',
      category: 'Silk',
      price: Money(12000),
      imageColor: 0xFF064E3B,
      sellByLength: true,
      minCutMeters: 1.0,
    );

Map<String, dynamic> _rpcResponse() => {
      'order_id': 'server-ord-002',
      'subtotal': 100,
      'shipping': 0,
      'total': 100,
      'expires_at': '2026-09-14T00:00:00Z',
      'status': 'pending',
    };

Future<Map<String, dynamic>> _capture(List<CartItem> items) async {
  final client = MockSupabaseClient();
  when(() => client.rpc('create_checkout_order', params: any(named: 'params')))
      .thenAnswer((_) => FakePostgrestFilterBuilder<dynamic>(_rpcResponse()));
  final service = CheckoutService(client: client);
  await service.placeOrder(
    items: items,
    paymentMethod: PaymentMethod.paymobCard,
    addressSnapshot: const {},
  );
  final captured = verify(() => client.rpc('create_checkout_order',
      params: captureAny(named: 'params'))).captured;
  return (captured.single as Map).cast<String, dynamic>();
}

/// Wave C payload contract: cut-length meters + client-estimated totals
/// and the sample flag must ride `p_items` so the (pending) server-side
/// validation can reject tampered lines.
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('metered line carries meters, line_total, and tiered_price', () async {
    final params = await _capture([
      CartItem(product: _cutFabric(), color: 'Emerald', length: '12.5'),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line['meters'], 12.5);
    // 12.5 m hits the 5% tier: 12000 * 0.95 = 11400/m, x 12.5 = 142500.
    expect(line['tiered_price'], 11400);
    expect(line['line_total'], 142500);
    expect(line.containsKey('sample'), isFalse);
  });

  test('sub-tier metered line omits tiered_price', () async {
    final params = await _capture([
      CartItem(product: _cutFabric(), color: 'Emerald', length: '5.0'),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line['meters'], 5.0);
    expect(line['line_total'], 60000);
    expect(line.containsKey('tiered_price'), isFalse);
  });

  test('sample lines flag sample: true with no metered fields', () async {
    final params = await _capture([
      CartItem(
          product: _cutFabric(),
          color: 'Emerald',
          length: 'sample',
          sample: true),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line['sample'], isTrue);
    expect(line.containsKey('meters'), isFalse);
    expect(line.containsKey('tiered_price'), isFalse);
  });

  test('fixed-size lines keep the legacy payload shape untouched', () async {
    const fixed = Product(
      id: 'fixed-01',
      name: 'Fixed',
      category: 'Silk',
      price: Money(129000),
      imageColor: 0xFF176B57,
    );
    final params = await _capture([
      const CartItem(
          product: fixed, color: 'Emerald', length: '2m', quantity: 2),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line, {
      'product_id': 'fixed-01',
      'size': '2m',
      'color': 'Emerald',
      'quantity': 2,
    });
  });
}
