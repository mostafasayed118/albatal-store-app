import 'package:al_batal_elite/core/entities/money.dart';
import 'package:al_batal_elite/features/payments/data/paymob_payment_service.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('PaymobPaymentService — error scrubbing (audit finding #4)', () {
    late _MockSupabaseClient client;

    setUp(() {
      client = _MockSupabaseClient();
    });

    test(
        'initiatePayment failure never leaks the raw exception into the message',
        () async {
      // A transport failure carrying internal URLs and secrets — the exact
      // kind of detail that must never reach the UI.
      final leakyException = Exception(
          'POST https://accept.paymob.com/api/auth 401 token=SECRET_VALUE');
      when(() => client.functions).thenThrow(leakyException);

      final service = PaymobPaymentService(client: client);
      final result = await service.initiatePayment(
        amount: Money.egp(100),
        method: PaymentMethod.paymobCard,
        orderId: 'ord-1',
        customerEmail: 'customer@example.com',
      );

      expect(result, isA<PaymentFailed>());
      final message = (result as PaymentFailed).message;
      expect(message, isNot(contains('https://')));
      expect(message, isNot(contains('SECRET_VALUE')));
    });
  });
}
