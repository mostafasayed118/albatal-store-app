/// Named app-wide durations (audit 2026-09-21: inline timing literals
/// that appeared in two features could drift apart silently).
abstract final class AppDurations {
  /// Search-as-you-type debounce shared by the storefront catalog query
  /// and the admin customer directory search.
  static const searchDebounce = Duration(milliseconds: 300);
}
