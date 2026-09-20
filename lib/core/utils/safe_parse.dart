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

/// Nullable twin of [safeInt]: correct ints pass through, other [num]s are
/// coerced via [num.toInt], and anything else (missing key, null, mistyped)
/// degrades to null so callers keep `as int?` semantics for well-typed
/// inputs while mistypes never throw [TypeError].
int? optInt(Map? map, String key) {
  final value = map?[key];
  if (value is int) return value;
  return value is num ? value.toInt() : null;
}

/// Nullable [double] twin of [optInt]: correct doubles pass through,
/// other [num]s are widened via [num.toDouble], anything else degrades to
/// null (see [optInt]).
double? optDouble(Map? map, String key) {
  final value = map?[key];
  if (value is double) return value;
  return value is num ? value.toDouble() : null;
}

/// Nullable twin of [safeString]: correct strings pass through, anything
/// else degrades to null — for optional text fields where the fallback
/// should stay "absent" rather than `''` (see [optInt]).
String? optString(Map? map, String key) {
  final value = map?[key];
  return value is String ? value : null;
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
