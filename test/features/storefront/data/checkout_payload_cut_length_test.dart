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
    address: null,
  );
  final captured = verify(() => client.rpc('create_checkout_order',
      params: captureAny(named: 'params'))).captured;
  return (captured.single as Map).cast<String, dynamic>();
}

/// Swatch-kit payload contract (migration 077 live): cut-length meters +
/// client-estimated totals and the sample flag ride `p_items` so the
/// server prices samples and cross-checks metered lines. The client
/// gate only fails closed for line types the server cannot price —
/// both flags are on, so every line below reaches the RPC.
void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('metered lines reach the RPC with the metered payload', () async {
    // 12000 minor/m x 12.5 m at the 5 % tier: tiered/m = 11400,
    // line_total = (12000*95*125+500)/1000 = 142500.
    final params = await _capture([
      CartItem(product: _cutFabric(), color: 'Emerald', length: '12.5'),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line['meters'], 12.5);
    expect(line['line_total'], 142500);
    expect(line['tiered_price'], 11400);
  });

  test('sub-tier metered lines omit tiered_price', () async {
    // 5.0 m earns no tier: line_total = (12000*100*50+500)/1000 = 60000,
    // and the undiscounted per-meter price rides no tiered_price key.
    final params = await _capture([
      CartItem(product: _cutFabric(), color: 'Emerald', length: '5.0'),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line['meters'], 5.0);
    expect(line['line_total'], 60000);
    expect(line.containsKey('tiered_price'), isFalse);
  });

  test('sample lines reach the RPC flagged sample-only', () async {
    final params = await _capture([
      CartItem(
        product: _cutFabric(),
        color: 'Emerald',
        length: 'sample',
        sample: true,
      ),
    ]);
    final line = (params['p_items'] as List).single as Map;
    expect(line, {
      'product_id': 'fabric-01',
      'size': 'sample',
      'color': 'Emerald',
      'quantity': 1,
      'sample': true,
    });
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
