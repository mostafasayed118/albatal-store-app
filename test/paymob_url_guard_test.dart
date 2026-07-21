import 'package:al_batal_elite/features/payments/domain/paymob_url_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymobUrlGuard.isSafePaymobCheckoutUrl', () {
    test('rejects empty URL', () {
      expect(PaymobUrlGuard.isSafePaymobCheckoutUrl(''), isFalse);
    });

    test('rejects whitespace-only URL', () {
      expect(PaymobUrlGuard.isSafePaymobCheckoutUrl('   '), isFalse);
    });

    test('rejects HTTP (non-TLS) URL even on the Paymob host', () {
      expect(
        PaymobUrlGuard.isSafePaymobCheckoutUrl(
          'http://accept.paymob.com/api/acceptance/iframes/85679?payment_token=x',
        ),
        isFalse,
      );
    });

    test('rejects HTTPS URL on an unexpected host', () {
      expect(
        PaymobUrlGuard.isSafePaymobCheckoutUrl(
          'https://evil.example.com/api/acceptance/iframes/85679?payment_token=x',
        ),
        isFalse,
      );
    });

    test('rejects a non-URL string', () {
      expect(
        PaymobUrlGuard.isSafePaymobCheckoutUrl('not a url'),
        isFalse,
      );
    });

    test('rejects a paymob: scheme URL', () {
      expect(
        PaymobUrlGuard.isSafePaymobCheckoutUrl('paymob://checkout?token=x'),
        isFalse,
      );
    });

    test('accepts a valid HTTPS Paymob accept URL', () {
      expect(
        PaymobUrlGuard.isSafePaymobCheckoutUrl(
          'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=abc123',
        ),
        isTrue,
      );
    });

    test('accepts a valid HTTPS secure-egypt Paymob URL', () {
      expect(
        PaymobUrlGuard.isSafePaymobCheckoutUrl(
          'https://secure-egypt.paymob.com/api/acceptance/iframes/85679?payment_token=abc',
        ),
        isTrue,
      );
    });
  });

  group('PaymobUrlGuard.redact', () {
    test('redacts the payment_token query param so it is safe to log', () {
      const url =
          'https://accept.paymob.com/api/acceptance/iframes/85679?payment_token=SECRET_TOKEN_VALUE';
      final redacted = PaymobUrlGuard.redact(url);
      expect(redacted, contains('payment_token='));
      expect(redacted, isNot(contains('SECRET_TOKEN_VALUE')));
    });

    test('returns a safe label for an unparseable URL', () {
      expect(PaymobUrlGuard.redact(''), equals('<invalid-url>'));
    });
  });
}
