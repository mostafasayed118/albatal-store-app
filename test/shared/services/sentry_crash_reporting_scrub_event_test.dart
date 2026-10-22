import 'package:al_batal_elite/shared/services/sentry_crash_reporting_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Covers the concrete [SentryCrashReportingService.scrubEvent] defense-in-depth
/// path (no network, no SDK init). The non-empty-DSN init block and the
/// post-init capture/setUser bodies cannot run in a default test build because
/// `EnvConfig.sentryDsn` is a compile-time constant that is empty here.
class _ThrowingExtraEvent extends SentryEvent {
  @override
  Map<String, dynamic>? get extra => throw StateError('extra unavailable');

  @override
  set extra(Map<String, dynamic>? value) =>
      throw StateError('extra unavailable');
}

class _ThrowingMessageBreadcrumb extends Breadcrumb {
  _ThrowingMessageBreadcrumb() : super(message: 'original');

  @override
  String? get message => throw StateError('message unavailable');

  @override
  set message(String? value) => throw StateError('message unavailable');
}

class _ThrowingCookiesRequest extends SentryRequest {
  _ThrowingCookiesRequest() : super(url: 'https://api.example.com');

  @override
  String? get cookies => throw StateError('cookies unavailable');

  @override
  set cookies(String? value) => throw StateError('cookies unavailable');
}

void main() {
  group('SentryCrashReportingService.scrubEvent', () {
    test('redacts sensitive tags and keeps clean tags', () {
      final event = SentryEvent(
        tags: {
          'authorization': 'Bearer abc',
          'user_email': 'a@b.com',
          'release_channel': 'beta',
        },
      );

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(scrubbed.tags!['authorization'], '[REDACTED]');
      expect(scrubbed.tags!['user_email'], '[REDACTED]');
      expect(scrubbed.tags!['release_channel'], 'beta');
    });

    test('null tags become an empty map', () {
      final event = SentryEvent();

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(scrubbed.tags, isEmpty);
    });

    test('reduces the user to the id only', () {
      final event = SentryEvent(
        user: SentryUser(
          id: 'user-uuid',
          email: 'customer@example.com',
          username: 'customer',
          name: 'Customer Name',
          ipAddress: '10.0.0.1',
        ),
      );

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(scrubbed.user!.id, 'user-uuid');
      expect(scrubbed.user!.email, isNull);
      expect(scrubbed.user!.username, isNull);
      expect(scrubbed.user!.name, isNull);
      expect(scrubbed.user!.ipAddress, isNull);
    });

    test('null user stays null', () {
      final scrubbed = SentryCrashReportingService.scrubEvent(SentryEvent());

      expect(scrubbed.user, isNull);
    });

    test('scrubs extra keys and embedded PII in values', () {
      final event = SentryEvent(
        // ignore: deprecated_member_use
        extra: {
          'token': 'abc',
          'note': 'reach me at customer@example.com',
          'order_count': 3,
        },
      );

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      // ignore: deprecated_member_use
      expect(scrubbed.extra!['token'], '[REDACTED]');
      // ignore: deprecated_member_use
      expect(scrubbed.extra!['note'], 'reach me at [email]');
      // ignore: deprecated_member_use
      expect(scrubbed.extra!['order_count'], 3);
    });

    test('scrubs map and string contexts, leaves other values', () {
      final event = SentryEvent(
        contexts: Contexts(),
      )
        ..contexts['custom_map'] = {
          'phone': '+201000000000',
          'route': '/checkout',
        }
        ..contexts['custom_string'] = 'mail me at customer@example.com'
        ..contexts['custom_number'] = 42;

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      final map = scrubbed.contexts['custom_map'] as Map;
      expect(map['phone'], '[REDACTED]');
      expect(map['route'], '/checkout');
      expect(
        scrubbed.contexts['custom_string'],
        'mail me at [email]',
      );
      expect(scrubbed.contexts['custom_number'], 42);
    });

    test('scrubs breadcrumb messages and data', () {
      final event = SentryEvent(
        breadcrumbs: [
          Breadcrumb(
            message: 'contact customer@example.com',
            data: {'session_token': 'abc', 'route': '/cart'},
          ),
        ],
      );

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      final crumb = scrubbed.breadcrumbs!.single;
      expect(crumb.message, 'contact [email]');
      expect(crumb.data!['session_token'], '[REDACTED]');
      expect(crumb.data!['route'], '/cart');
    });

    test('a failing breadcrumb is kept and does not drop the event', () {
      final bad = _ThrowingMessageBreadcrumb();
      final event = SentryEvent(breadcrumbs: [bad]);

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(scrubbed.breadcrumbs, hasLength(1));
      expect(identical(scrubbed.breadcrumbs!.single, bad), isTrue);
    });

    test('clears request cookies/query/fragment and scrubs headers/data', () {
      final event = SentryEvent(
        request: SentryRequest(
          url: 'https://api.example.com/orders',
          cookies: 'session=abc',
          queryString: 'token=abc',
          fragment: 'access_token',
          headers: {
            'authorization': 'Bearer abc',
            'x-request-id': 'req-1',
          },
          data: {
            'email': 'customer@example.com',
            'order_id': 'ord-1',
          },
        ),
      );

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      final request = scrubbed.request!;
      expect(request.cookies, isNull);
      expect(request.queryString, isNull);
      expect(request.fragment, isNull);
      expect(request.headers['authorization'], '[REDACTED]');
      expect(request.headers['x-request-id'], 'req-1');
      expect(request.data['email'], '[REDACTED]');
      expect(request.data['order_id'], 'ord-1');
    });

    test('redacts PII inside a string request body', () {
      final event = SentryEvent(
        request: SentryRequest(
          url: 'https://api.example.com/orders',
          data: 'customer customer@example.com',
        ),
      );

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(scrubbed.request!.data, 'customer [email]');
    });

    test('leaves a null request alone', () {
      final scrubbed = SentryCrashReportingService.scrubEvent(SentryEvent());

      expect(scrubbed.request, isNull);
    });

    test('a failing request scrub keeps the original request', () {
      final request = _ThrowingCookiesRequest();
      final event = SentryEvent(request: request);

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(identical(scrubbed.request, request), isTrue);
    });

    test('a scrub failure returns the original event', () {
      final event = _ThrowingExtraEvent();

      final scrubbed = SentryCrashReportingService.scrubEvent(event);

      expect(identical(scrubbed, event), isTrue);
    });
  });

  group('SentryCrashReportingService without a DSN', () {
    test('init is a no-op and repeatable', () {
      final service = SentryCrashReportingService();

      expect(service.init, returnsNormally);
      expect(service.init, returnsNormally);
    });

    test('captureError returns before touching Sentry when uninitialized', () {
      final service = SentryCrashReportingService();

      expect(
        () => service.captureError(
          Exception('boom'),
          StackTrace.current,
          context: {'token': 'abc'},
        ),
        returnsNormally,
      );
    });

    test('setUser returns before touching Sentry when uninitialized', () {
      final service = SentryCrashReportingService();

      expect(() => service.setUser('user-1'), returnsNormally);
      expect(() => service.setUser(null), returnsNormally);
    });
  });
}
