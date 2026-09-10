import 'package:al_batal_elite/shared/services/logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the release-breadcrumb PII scrub (audit P2): emails and
/// phone-like runs must never leave the device through Log → Sentry.
void main() {
  group('Log.redact', () {
    test('replaces email addresses', () {
      expect(
        Log.redact('Customer customer.x+tag@example.co.uk signed in'),
        'Customer [email] signed in',
      );
    });

    test('replaces phone-like runs with separators', () {
      expect(Log.redact('call +20 10 1234 5678 now'), 'call [phone] now');
      expect(Log.redact('call 01012345678 now'), 'call [phone] now');
    });

    test('keeps non-PII text intact', () {
      const message = 'readOrders failed: order ord-9f2c total EGP 1234.56 '
          'at 12:30:45.123';
      expect(Log.redact(message), message);
    });
  });
}
