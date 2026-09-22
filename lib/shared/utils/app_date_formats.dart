import 'package:intl/intl.dart';

/// Locale-keyed [DateFormat] cache (audit 2026-09-21, P2).
///
/// List surfaces used to construct a fresh `DateFormat` per row, per
/// build. `DateFormat.format` is stateless, so one instance per
/// (pattern, locale) pair serves every row; instances are memoized here
/// instead of being rebuilt. Locale-keyed on purpose: the app switches
/// between AR and EN at runtime, and month names follow the locale the
/// instance was built with.
abstract final class AppDateFormats {
  static final Map<String, DateFormat> _cache = {};

  static DateFormat _for(String pattern, String locale) =>
      _cache.putIfAbsent('$pattern|$locale', () => DateFormat(pattern, locale));

  /// `d MMM y` — short closed-order date, localized month names.
  static DateFormat dayMonthYear(String locale) => _for('d MMM y', locale);

  /// `d MMM y, HH:mm` — status timeline stamp.
  static DateFormat dayMonthYearTime(String locale) =>
      _for('d MMM y, HH:mm', locale);

  /// `yyyy-MM-dd HH:mm:ss` — admin order record timestamp.
  static DateFormat timestampSeconds(String locale) =>
      _for('yyyy-MM-dd HH:mm:ss', locale);
}
