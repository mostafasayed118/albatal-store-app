/// Total (never-throwing) accessors for loosely-typed row/cache maps.
///
/// Supabase rows, RPC payloads, and SharedPreferences caches all arrive
/// as `Map`s whose values may be missing or mistyped. These helpers
/// centralize the `as T? ?? fallback` idiom (audit P5) so call sites
/// never hand-write casts: correctly-typed values pass through, anything
/// else degrades to the fallback instead of throwing a [TypeError] into
/// the UI layer.
String safeString(Map? map, String key, {String fallback = ''}) {
  final value = map?[key];
  return value is String ? value : fallback;
}

/// Returns an [int] for [key], coercing other [num]s via [num.toInt].
int safeInt(Map? map, String key, {int fallback = 0}) {
  final value = map?[key];
  return value is int ? value : (value is num ? value.toInt() : fallback);
}

/// Returns a [bool] for [key]; any non-bool degrades to [fallback].
bool safeBool(Map? map, String key, {bool fallback = false}) {
  final value = map?[key];
  return value is bool ? value : fallback;
}

/// Normalizes an untyped decoded value to a string-keyed map.
///
/// Correctly-typed maps pass through by reference; maps with non-String
/// keys are stringified; anything else becomes an empty map — never throws.
Map<String, dynamic> safeMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return const {};
}

/// Parses an ISO-8601 timestamp for [key] without throwing.
///
/// Real [DateTime] values pass through; strings go through
/// [DateTime.tryParse]; anything else (or an unparseable string) yields
/// null — the caller decides the fallback.
DateTime? safeDateTime(Map? map, String key) {
  final value = map?[key];
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
