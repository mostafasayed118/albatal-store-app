import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporting_service.dart';
import 'env_config.dart';
import 'logger.dart';

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
      // a safety net. Log warning so misconfiguration is visible.
      Log.w('Sentry disabled — no DSN', category: LogCategory.app);
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

        options.tracesSampleRate = 0.1;

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
  /// Public static entry point so `bootstrap.dart` can route its
  /// `beforeSend` through the same scrub (single implementation).
  /// Covers tags/user (key-based) plus extra/contexts/breadcrumbs/request
  /// (value-based email/phone scrub). Never throws — a scrub failure
  /// returns the original event rather than dropping telemetry.
  static SentryEvent scrubEvent(SentryEvent event) {
    try {
      final sensitivePattern = RegExp(
        r'token|secret|card|cvv|authorization|address|email|phone|password|name|username|reference',
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

      // Extra: key-based + value-based PII scrub.
      // ignore: deprecated_member_use
      final extra = event.extra;
      if (extra != null) {
        // ignore: deprecated_member_use
        event.extra = CrashReportingService.scrubContext(
          Map<String, dynamic>.from(extra),
        );
      }

      // Contexts: scrub custom (non-default) entries; drop nothing so
      // device/os metadata survives. Each custom value map goes through
      // the same key/value scrub.
      try {
        final keys = List<String>.from(event.contexts.keys);
        for (final key in keys) {
          final value = event.contexts[key];
          if (value is Map) {
            event.contexts[key] = CrashReportingService.scrubContext(
              Map<String, dynamic>.from(
                value.map((k, v) => MapEntry('$k', v)),
              ),
            );
          } else if (value is String) {
            final scrubbed = CrashReportingService.scrubContext(
              {'value': value},
            )['value'];
            event.contexts[key] = scrubbed;
          }
        }
      } catch (_) {
        // Context shape is SDK-owned; never let scrub break the event.
      }

      // Breadcrumbs: scrub message text (emails/phones) and data maps.
      // Mutated in place to preserve timestamp/level/type/unknown.
      final crumbs = event.breadcrumbs;
      if (crumbs != null) {
        for (final c in crumbs) {
          try {
            if (c.message != null) c.message = Log.redact(c.message!);
            if (c.data != null) {
              c.data = CrashReportingService.scrubContext(
                Map<String, dynamic>.from(c.data!),
              );
            }
          } catch (_) {
            // Keep the original breadcrumb on scrub failure.
          }
        }
      }

      // Request: strip cookies/query/fragment (often carry tokens), scrub
      // headers + data. SentryRequest.data has no setter, so replace the
      // request via copyWith when data needs scrubbing.
      final req = event.request;
      if (req != null) {
        try {
          req.cookies = null;
          req.queryString = null;
          req.fragment = null;
          final headers = Map<String, String>.from(req.headers);
          final scrubbedHeaders =
              CrashReportingService.scrubContext(headers);
          req.headers = scrubbedHeaders.map(
            (k, v) => MapEntry(k, v?.toString() ?? '[REDACTED]'),
          );
          final data = req.data;
          if (data is Map) {
            final scrubbedData = CrashReportingService.scrubContext(
              Map<String, dynamic>.from(
                data.map((k, v) => MapEntry('$k', v)),
              ),
            );
            // ignore: deprecated_member_use
            event.request = req.copyWith(data: scrubbedData);
          } else if (data is String) {
            // ignore: deprecated_member_use
            event.request = req.copyWith(data: Log.redact(data));
          }
        } catch (_) {
          // Keep the original request on scrub failure.
        }
      }

      event.tags = scrubbedTags;
      event.user = scrubbedUser;
      return event;
    } catch (_) {
      return event;
    }
  }

  /// Instance forwarder kept for the `beforeSend` closure below.
  SentryEvent _scrubEvent(SentryEvent event) => scrubEvent(event);
}
