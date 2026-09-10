import 'package:al_batal_elite/features/payments/data/payment_status_watcher.dart';
import 'package:al_batal_elite/features/payments/data/paymob_payment_service.dart';
import 'package:al_batal_elite/features/payments/domain/entities/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M3 watcher compat forwarder', () {
    test('forwarder matches watcher on success row', () {
      const row = {'status': 'success', 'transaction_id': 'TX1'};
      final viaService = PaymobPaymentService.terminalResultForRow(row);
      final viaWatcher = PaymentStatusWatcher.terminalResultForRow(row);
      expect(viaService, isA<PaymentSuccess>());
      expect(viaWatcher, isA<PaymentSuccess>());
      expect((viaService as PaymentSuccess).transactionId, 'TX1');
      expect((viaWatcher as PaymentSuccess).transactionId, 'TX1');
    });

    test('forwarder matches watcher on failed row', () {
      const row = {'status': 'failed'};
      final viaService = PaymobPaymentService.terminalResultForRow(row);
      final viaWatcher = PaymentStatusWatcher.terminalResultForRow(row);
      expect(viaService, isA<PaymentFailed>());
      expect(viaWatcher, isA<PaymentFailed>());
      expect((viaService as PaymentFailed).message,
          'Payment was declined by the gateway');
      expect((viaWatcher as PaymentFailed).message,
          'Payment was declined by the gateway');
    });

    test('forwarder matches watcher on pending/missing rows', () {
      expect(
          PaymobPaymentService.terminalResultForRow(
              const {'status': 'pending'}),
          isNull);
      expect(
          PaymentStatusWatcher.terminalResultForRow(
              const {'status': 'pending'}),
          isNull);
      expect(PaymobPaymentService.terminalResultForRow(const {}), isNull);
      expect(PaymentStatusWatcher.terminalResultForRow(const {}), isNull);
    });
  });
}
