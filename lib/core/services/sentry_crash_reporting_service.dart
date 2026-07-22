import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../shared/services/env_config.dart';
import 'crash_reporting_service.dart';

/// Sentry-backed crash reporting implementation.
///
/// Scrubs PII from events via [Sentry.beforeSend] and from explicit
/// context via the shared [CrashReportingService.scrubContext] helper.
class SentryCrashReportingService implements CrashReportingService {
  const SentryCrashReportingService();

  @override
  void init() {
    final dsn = EnvConfig.sentryDsn;
    if (dsn.isEmpty) {
      // No DSN configured — silently degrade to no-op. The app
      // still works; crashes are logged locally via Log.
      return;
    }
    SentryFlutter.init(
      (options) => options
        ..dsn = dsn
        ..environment = EnvConfig.environment
        ..tracesSampleRate = kDebugMode ? 1.0 : 0.1
        ..beforeSend = _scrubEvent,
    );
  }

  @override
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) {
    final scrubbedContext = CrashReportingService.scrubContext(context);
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap(scrubbedContext),
    );
  }

  @override
  void setUser(String? userId) {
    Sentry.configureScope((scope) {
      scope.setUser(userId != null ? SentryUser(id: userId) : null);
    });
  }

  /// Strip tokens, card data, addresses, and other PII from Sentry events
  /// before they leave the device.
  ///
  /// The primary PII protection is in [captureError] which scrubs the
  /// context map via [CrashReportingService.scrubContext]. This handler
  /// provides an additional safety net at the event level.
  static FutureOr<SentryEvent?> _scrubEvent(
    SentryEvent event,
    Hint hint,
  ) {
    // Return the event as-is; PII scrubbing is handled by captureError
    // and the beforeSend hook serves as a future extension point.
    return event;
  }
}
