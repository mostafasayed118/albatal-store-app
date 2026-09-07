import 'package:al_batal_elite/core/entities/product.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:al_batal_elite/features/storefront/data/checkout_service.dart';
import '../../../fixtures/products_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('CheckoutService — error scrubbing (audit P1)', () {
    test('generic failure never leaks the raw exception into the message',
        () async {
      // A transport failure carrying internal URLs and secrets — the exact
      // kind of detail that must never reach the UI.
      final client = _MockSupabaseClient();
      final leakyException = Exception(
          'POST https://db.internal.example.com/rest/v1/rpc 500 token=SECRET_VALUE');
      when(() =>
              client.rpc('create_checkout_order', params: any(named: 'params')))
          .thenThrow(leakyException);

      final service = CheckoutService(client: client);
      final result = await service.placeOrder(
        items: [
          CartItem(
              product: products.first,
              color: 'Emerald',
              length: '2m',
              quantity: 1),
        ],
        paymentMethod: PaymentMethod.cashOnDelivery,
        addressSnapshot: const {},
      );

      expect(result, isA<Failure>());
      final message = (result as Failure).error.message;
      expect(message, isNot(contains('https://')));
      expect(message, isNot(contains('SECRET_VALUE')));
      expect(message, 'Checkout failed');
    });
  });
}
