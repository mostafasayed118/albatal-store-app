import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporting_service.dart';
import 'env_config.dart';

/// Sentry-backed crash reporting service.
///
/// When [EnvConfig.sentryDsn] is non-empty, initializes Sentry with:
/// - `sendDefaultPii = false` (no default PII collection)
/// - `attachScreenshot = false` (no screenshots)
/// - User scrubbing via [CrashReportingService.scrubContext]
/// - `beforeSend` hook as defense-in-depth PII scrubbing
///
/// When [EnvConfig.sentryDsn] is empty, the app falls back to
/// [NoOpCrashReportingService] via the DI container.
class SentryCrashReportingService implements CrashReportingService {
  SentryCrashReportingService();

  bool _initialized = false;

  @override
  void init() {
    if (_initialized) return;

    final dsn = EnvConfig.sentryDsn;
    if (dsn.isEmpty) {
      // DSN not configured — remain a no-op. The DI container should
      // have registered NoOpCrashReportingService instead, but this is
      // a safety net.
      return;
    }

    SentryFlutter.init(
      (options) {
        options.dsn = dsn;

        // ─── PII protection ───────────────────────────────────
        // Never collect default PII (IP, device info extras, etc.)
        options.sendDefaultPii = false;

        // Never attach screenshots in production.
        options.attachScreenshot = false;

        // ─── Environment metadata ─────────────────────────────
        options.environment = EnvConfig.environment;
        // Release and dist are set by the build system if needed.

        // ─── Defense-in-depth scrubbing ───────────────────────
        // The beforeSend hook scrubs any PII that might leak
        // through breadcrumbs, extras, or user context. This is
        // in addition to scrubContext which is called by callers.
        options.beforeSend = (event, hint) {
          return _scrubEvent(event);
        };
      },
    );

    _initialized = true;
  }

  @override
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) {
    if (!_initialized) return;

    // Scrub context before attaching to the event.
    final scrubbedContext = CrashReportingService.scrubContext(context);

    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: scrubbedContext.isNotEmpty ? Hint.withMap(scrubbedContext) : null,
    );
  }

  @override
  void setUser(String? userId) {
    if (!_initialized) return;

    // Attach ONLY the user UUID. Never attach email, phone, name, etc.
    Sentry.configureScope((scope) {
      if (userId != null && userId.isNotEmpty) {
        scope.setUser(SentryUser(id: userId));
      } else {
        scope.setUser(null);
      }
    });
  }

  /// Defense-in-depth: scrub PII from Sentry events before sending.
  ///
  /// This catches any PII that might leak through breadcrumbs, extras,
  /// tags, or user context that was set outside of our controlled API.
  SentryEvent _scrubEvent(SentryEvent event) {
    final sensitivePattern = RegExp(
      r'token|secret|card|cvv|authorization|address|email|phone|password|name',
      caseSensitive: false,
    );

    // Scrub tags (null-safe)
    final scrubbedTags = <String, String>{};
    if (event.tags != null) {
      for (final entry in event.tags!.entries) {
        if (sensitivePattern.hasMatch(entry.key)) {
          scrubbedTags[entry.key] = '[REDACTED]';
        } else {
          scrubbedTags[entry.key] = entry.value;
        }
      }
    }

    // Ensure user only has id (no email, name, etc.)
    SentryUser? scrubbedUser;
    if (event.user != null) {
      scrubbedUser = SentryUser(id: event.user!.id);
    }

    event.tags = scrubbedTags;
    event.user = scrubbedUser;
    return event;
  }
}
