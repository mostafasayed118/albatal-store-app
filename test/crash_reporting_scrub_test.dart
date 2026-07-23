import 'package:al_batal_elite/core/services/crash_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashReportingService.scrubContext', () {
    test('redacts sensitive keys', () {
      final context = <String, dynamic>{
        'authToken': 'abc123',
        'userSecret': 'xyz',
        'cardNumber': '4111...',
        'cvv': '123',
        'authorization': 'Bearer ...',
        'address': '123 Main St',
        'email': 'user@example.com',
        'phone': '+201000000000',
        'password': 'hunter2',
      };
      final scrubbed = CrashReportingService.scrubContext(context);
      expect(scrubbed['authToken'], '[REDACTED]');
      expect(scrubbed['userSecret'], '[REDACTED]');
      expect(scrubbed['cardNumber'], '[REDACTED]');
      expect(scrubbed['cvv'], '[REDACTED]');
      expect(scrubbed['authorization'], '[REDACTED]');
      expect(scrubbed['address'], '[REDACTED]');
      expect(scrubbed['email'], '[REDACTED]');
      expect(scrubbed['phone'], '[REDACTED]');
      expect(scrubbed['password'], '[REDACTED]');
    });

    test('preserves non-sensitive keys', () {
      final context = <String, dynamic>{
        'userId': 'uuid-123',
        'route': '/checkout',
        'orderId': 'order-abc',
        'environment': 'staging',
      };
      final scrubbed = CrashReportingService.scrubContext(context);
      expect(scrubbed['userId'], 'uuid-123');
      expect(scrubbed['route'], '/checkout');
      expect(scrubbed['orderId'], 'order-abc');
      expect(scrubbed['environment'], 'staging');
    });

    test('handles null context', () {
      expect(CrashReportingService.scrubContext(null), isEmpty);
    });

    test('handles empty context', () {
      expect(CrashReportingService.scrubContext(<String, dynamic>{}), isEmpty);
    });
  });

  group('NoOpCrashReportingService', () {
    test('all methods are no-ops and do not throw', () {
      final service = const NoOpCrashReportingService();
      service.init();
      service.captureError(Exception('test'), StackTrace.current);
      service.setUser('user-123');
      service.setUser(null);
    });
  });
}
