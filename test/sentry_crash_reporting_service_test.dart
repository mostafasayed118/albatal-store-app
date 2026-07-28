import 'package:al_batal_elite/shared/services/crash_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashReportingService.scrubContext', () {
    test('returns empty map for null input', () {
      final result = CrashReportingService.scrubContext(null);
      expect(result, isEmpty);
    });

    test('scrubs token key', () {
      final result = CrashReportingService.scrubContext({
        'token': 'abc123',
        'safe_key': 'safe_value',
      });
      expect(result['token'], '[REDACTED]');
      expect(result['safe_key'], 'safe_value');
    });

    test('scrubs secret key', () {
      final result = CrashReportingService.scrubContext({
        'api_secret': 'xyz789',
      });
      expect(result['api_secret'], '[REDACTED]');
    });

    test('scrubs card key', () {
      final result = CrashReportingService.scrubContext({
        'card_number': '4111111111111111',
      });
      expect(result['card_number'], '[REDACTED]');
    });

    test('scrubs cvv key', () {
      final result = CrashReportingService.scrubContext({
        'cvv': '123',
      });
      expect(result['cvv'], '[REDACTED]');
    });

    test('scrubs authorization key', () {
      final result = CrashReportingService.scrubContext({
        'authorization': 'Bearer abc',
      });
      expect(result['authorization'], '[REDACTED]');
    });

    test('scrubs address key', () {
      final result = CrashReportingService.scrubContext({
        'address': '123 Main St',
      });
      expect(result['address'], '[REDACTED]');
    });

    test('scrubs email key', () {
      final result = CrashReportingService.scrubContext({
        'email': 'user@example.com',
      });
      expect(result['email'], '[REDACTED]');
    });

    test('scrubs phone key', () {
      final result = CrashReportingService.scrubContext({
        'phone': '+1234567890',
      });
      expect(result['phone'], '[REDACTED]');
    });

    test('scrubs password key', () {
      final result = CrashReportingService.scrubContext({
        'password': 'secret123',
      });
      expect(result['password'], '[REDACTED]');
    });

    test('is case-insensitive', () {
      final result = CrashReportingService.scrubContext({
        'TOKEN': 'abc',
        'Secret': 'xyz',
        'Card': '123',
        'CVV': '456',
        'Email': 'test@test.com',
      });
      expect(result['TOKEN'], '[REDACTED]');
      expect(result['Secret'], '[REDACTED]');
      expect(result['Card'], '[REDACTED]');
      expect(result['CVV'], '[REDACTED]');
      expect(result['Email'], '[REDACTED]');
    });

    test('preserves non-sensitive keys', () {
      final result = CrashReportingService.scrubContext({
        'order_id': '12345',
        'amount': 1000,
        'currency': 'EGP',
        'status': 'pending',
      });
      expect(result['order_id'], '12345');
      expect(result['amount'], 1000);
      expect(result['currency'], 'EGP');
      expect(result['status'], 'pending');
    });

    test('handles mixed sensitive and non-sensitive keys', () {
      final result = CrashReportingService.scrubContext({
        'order_id': '12345',
        'user_token': 'abc123',
        'amount': 1000,
        'card_number': '4111111111111111',
        'email': 'user@example.com',
      });
      expect(result['order_id'], '12345');
      expect(result['user_token'], '[REDACTED]');
      expect(result['amount'], 1000);
      expect(result['card_number'], '[REDACTED]');
      expect(result['email'], '[REDACTED]');
    });

    test('returns empty map for empty input', () {
      final result = CrashReportingService.scrubContext({});
      expect(result, isEmpty);
    });
  });

  group('NoOpCrashReportingService', () {
    test('does not throw on init', () {
      final service = const NoOpCrashReportingService();
      expect(() => service.init(), returnsNormally);
    });

    test('does not throw on captureError', () {
      final service = const NoOpCrashReportingService();
      expect(
        () => service.captureError(
          Exception('test'),
          StackTrace.current,
          context: {'key': 'value'},
        ),
        returnsNormally,
      );
    });

    test('does not throw on setUser', () {
      final service = const NoOpCrashReportingService();
      expect(() => service.setUser('user-123'), returnsNormally);
      expect(() => service.setUser(null), returnsNormally);
    });
  });
}
