import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/error/app_error.dart';

/// Log levels for filtering output.
enum LogLevel { debug, info, warning, error }

/// Log categories for filtering and grouping.
enum LogCategory {
  app,
  navigation,
  auth,
  cubit,
  network,
  payment,
  analytics,
  error,
}

/// Professional logger with levels, categories, and structured output.
///
/// Usage:
///   Log.d('User signed in', category: LogCategory.auth);
///   Log.e('Payment failed', error: e, stackTrace: stackTrace);
///   Log.i('Navigated to /checkout', category: LogCategory.navigation);
class Log {
  const Log._();

  /// Minimum log level to output. Set to [LogLevel.warning] in production.
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  /// Set the minimum log level.
  static void setLevel(LogLevel level) => _minLevel = level;

  /// Whether to include timestamps in output.
  static bool includeTimestamp = true;

  /// Whether to include category in output.
  static bool includeCategory = true;

  // ─── Core logging methods ──────────────────────────────

  static void d(String message, {LogCategory category = LogCategory.app}) {
    _log(LogLevel.debug, category, message);
  }

  static void i(String message, {LogCategory category = LogCategory.app}) {
    _log(LogLevel.info, category, message);
  }

  static void w(String message, {LogCategory category = LogCategory.app}) {
    _log(LogLevel.warning, category, message);
  }

  static void e(String message,
      {LogCategory category = LogCategory.error,
      dynamic error,
      StackTrace? stackTrace}) {
    _log(LogLevel.error, category, message);
    if (error != null) {
      // Release breadcrumbs leave the device: never interpolate the raw
      // error object (it can carry URLs, tokens, or PII). Log the
      // user-safe AppError message when available, otherwise just the
      // runtime type; full detail stays in debugPrint/Sentry envelope.
      final summary = kReleaseMode ? _safeErrorSummary(error) : '$error';
      _log(LogLevel.error, category, '  Error: $summary');
    }
    if (stackTrace != null) {
      final trace = stackTrace.toString().split('\n').take(10).join('\n');
      _log(LogLevel.error, category, '  Stack:\n$trace');
    }
  }

  // ─── Structured logging methods ────────────────────────

  static void auth(String message, {LogLevel level = LogLevel.info}) {
    _log(level, LogCategory.auth, message);
  }

  static void nav(String message) {
    _log(LogLevel.info, LogCategory.navigation, message);
  }

  static void cubit(String cubitName, String message,
      {LogLevel level = LogLevel.debug}) {
    _log(level, LogCategory.cubit, '[$cubitName] $message');
  }

  static void api(String method, String url, {int? statusCode, dynamic body}) {
    final statusStr = statusCode != null ? ' → $statusCode' : '';
    _log(LogLevel.info, LogCategory.network, '$method $url$statusStr');
    if (body != null && kDebugMode) {
      _log(LogLevel.debug, LogCategory.network, '  Body: $body');
    }
  }

  static void payment(String message, {LogLevel level = LogLevel.info}) {
    _log(level, LogCategory.payment, message);
  }

  // ─── PII scrubbing ─────────────────────────────────────

  static final RegExp _emailPattern = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  /// Phone-like runs: 10+ chars of digits/separator characters, not glued
  /// to a word character (so UUIDs and timestamps stay intact).
  static final RegExp _phonePattern = RegExp(
    r'(?<![\w@])\+?\d[\d\s().-]{8,}\d(?!\w)',
  );

  /// Replaces email addresses and phone numbers in free text with
  /// `[email]` / `[phone]`.
  ///
  /// Release breadcrumbs leave the device (audit P2), so every message
  /// passes through here before [Sentry.addBreadcrumb]. Deliberately
  /// over-redacts: a support ticket id that looks like a phone number is
  /// cheaper to lose than a customer's PII.
  static String redact(String message) => message
      .replaceAllMapped(_emailPattern, (_) => '[email]')
      .replaceAllMapped(_phonePattern, (_) => '[phone]');

  /// Release-safe error summary: user-safe message for [AppError],
  /// otherwise just the runtime type (never the raw `toString()`).
  static String _safeErrorSummary(Object? error) {
    if (error is AppError) return redact('${error.runtimeType}: ${error.message}');
    return error.runtimeType.toString();
  }

  // ─── Private implementation ────────────────────────────

  static void _log(LogLevel level, LogCategory category, String message) {
    if (level.index < _minLevel.index) return;
    if (kReleaseMode) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: redact(message),
        category: category.name,
        level: switch (level) {
          LogLevel.debug => SentryLevel.debug,
          LogLevel.info => SentryLevel.info,
          LogLevel.warning => SentryLevel.warning,
          LogLevel.error => SentryLevel.error,
        },
      ));
      return;
    }

    final parts = <String>[];

    if (includeTimestamp) {
      parts.add(_timestamp());
    }

    parts.add(_levelIcon(level));

    if (includeCategory) {
      parts.add('[${category.name.toUpperCase()}]');
    }

    parts.add(message);

    final output = parts.join(' ');

    switch (level) {
      case LogLevel.debug:
        debugPrint(output);
        break;
      case LogLevel.info:
        debugPrint(output);
        break;
      case LogLevel.warning:
        debugPrint('⚠️ $output');
        break;
      case LogLevel.error:
        debugPrint('🔴 $output');
        break;
    }
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }

  static String _levelIcon(LogLevel level) => switch (level) {
        LogLevel.debug => '🔍',
        LogLevel.info => 'ℹ️',
        LogLevel.warning => '⚠️',
        LogLevel.error => '🔴',
      };
}
