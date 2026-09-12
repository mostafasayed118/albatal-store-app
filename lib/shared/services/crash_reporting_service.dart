/// Cross-cutting service for capturing uncaught errors and crashes.
///
/// The default implementation is [NoOpCrashReportingService], which discards
/// all events. A real provider (e.g. Sentry) is swapped in via DI when the
/// dependency is approved and added to `pubspec.yaml` — that integration is
/// human-gated and performed separately. Until then the app works without any
/// external crash-reporting dependency, and crash reporting simply complements
/// [Log] rather than replacing it.
abstract class CrashReportingService {
  /// Initialize the provider. Called before [runApp] in `main.dart`.
  void init();

  /// Capture an error with its stack trace and optional context.
  ///
  /// The optional [context] map is scrubbed via [scrubContext] before being
  /// forwarded to telemetry, so callers do not need to pre-redact PII.
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  });

  /// Set or clear the current user identifier for crash grouping.
  void setUser(String? userId);

  /// Scrub sensitive data from a context map before sending it to telemetry.
  ///
  /// Redacts any key matching (case-insensitively) the patterns: `token`,
  /// `secret`, `card`, `cvv`, `authorization`, `address`, `email`, `phone`,
  /// `password`, `name`, `full_name`, `username`, `reference`. The value is
  /// replaced with `'[REDACTED]'`; all other entries are preserved verbatim
  /// except that string values still get value-based PII scrubbing for
  /// embedded emails/phones.
  ///
  /// This is a static method so it can be unit-tested without instantiating a
  /// provider, and so callers can scrub context before it ever reaches a
  /// concrete implementation.
  static Map<String, dynamic> scrubContext(Map<String, dynamic>? context) {
    if (context == null) return {};
    final scrubbed = <String, dynamic>{};
    final sensitivePattern = RegExp(
      r'token|secret|card|cvv|authorization|address|email|phone|password|name|username|reference',
      caseSensitive: false,
    );
    for (final entry in context.entries) {
      if (sensitivePattern.hasMatch(entry.key)) {
        scrubbed[entry.key] = '[REDACTED]';
      } else {
        scrubbed[entry.key] = _scrubValue(entry.value);
      }
    }
    return scrubbed;
  }

  /// Value-based PII scrub for free-text values: embedded emails/phones
  /// are redacted even when the key itself is not sensitive.
  static Object? _scrubValue(Object? value) {
    if (value is! String) return value;
    return value
        .replaceAll(
          RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
          '[email]',
        )
        .replaceAll(
          RegExp(r'(?<![\w@])\+?\d[\d\s().-]{8,}\d(?!\w)'),
          '[phone]',
        );
  }
}

/// No-operation implementation that discards all crash events.
///
/// Used as the default when no crash-reporting provider is configured. This
/// ensures the app works without a Sentry/Crashlytics dependency. All methods
/// are intentionally empty; errors are still surfaced through [Log].
class NoOpCrashReportingService implements CrashReportingService {
  const NoOpCrashReportingService();

  @override
  void init() {}

  @override
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) {
    // No-op: errors are logged via Log but not sent to remote telemetry.
  }

  @override
  void setUser(String? userId) {}
}
