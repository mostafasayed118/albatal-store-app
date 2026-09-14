import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger.dart';

/// Key/value source for [RemoteConfigService] (feature-batch §13).
abstract interface class RemoteConfigFetcher {
  /// Returns the full config map, or throws — the service owns
  /// deciding what a failure means.
  Future<Map<String, String>> fetch();
}

/// Supabase `app_config` key/value table (proposal 052b).
final class SupabaseRemoteConfigFetcher implements RemoteConfigFetcher {
  SupabaseRemoteConfigFetcher({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Map<String, String>> fetch() async {
    final rows = await _client.from('app_config').select('key, value');
    // Defensive decode (audit 2026-09-14): rows is untyped, so a
    // malformed payload would throw a TypeError — an Error, not an
    // Exception — that the caller's catch guard cannot treat as a
    // normal fetch failure. Skip malformed rows instead; the service
    // falls back to defaults for the missing keys.
    final Object payload = rows; // erase the declared type: trust nothing
    final list = payload is List ? payload : const <dynamic>[];
    return {
      for (final row in list)
        if (row is Map && row['key'] is String && row['value'] is String)
          row['key'] as String: row['value'] as String,
    };
  }
}

/// Typed remote config with defaults + a 10-minute TTL cache
/// (feature-batch §13). Every read degrades to the default when the
/// backend is unreachable — the app must never boot-block on config.
class RemoteConfigService {
  RemoteConfigService({
    RemoteConfigFetcher? fetcher,
    Duration ttl = const Duration(minutes: 10),
    Future<String?> Function()? versionProvider,
  })  : _fetcher = fetcher ?? SupabaseRemoteConfigFetcher(),
        _ttl = ttl,
        _versionProvider = versionProvider ?? _defaultVersionProvider;

  static Future<String?> _defaultVersionProvider() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } on Exception {
      return null;
    }
  }

  final RemoteConfigFetcher _fetcher;
  final Duration _ttl;
  final Future<String?> Function() _versionProvider;

  Map<String, String> _cache = const {};
  DateTime? _fetchedAt;
  bool? _maintenanceMode;
  bool? _updateRequired;

  static const keyMaintenanceMode = 'maintenance_mode';
  static const keyMinSupportedVersion = 'min_supported_version';

  /// Refreshes the cache when stale. Failures keep the last values
  /// (or defaults) and are swallowed — config is advisory.
  Future<void> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _fetchedAt != null && now.difference(_fetchedAt!) < _ttl) {
      return;
    }
    try {
      _cache = await _fetcher.fetch();
      _fetchedAt = now;
      _maintenanceMode = null; // invalidate typed reads
      _updateRequired = null;
    } catch (e, st) {
      // Catch-all, not `on Exception`: a malformed payload can throw a
      // TypeError (an Error), which advisory config must swallow like
      // any other fetch failure — the app never boot-blocks on config.
      Log.w('remote config fetch failed: $e');
      Log.d(st.toString());
    }
  }

  bool get maintenanceMode {
    _maintenanceMode ??= _cache[keyMaintenanceMode]?.toLowerCase() == 'true';
    return _maintenanceMode!;
  }

  /// True when the running app version is older than the configured
  /// minimum (pure semver-ish numeric compare, non-numeric → older).
  Future<bool> updateRequired() async {
    if (_updateRequired != null) return _updateRequired!;
    final min = _cache[keyMinSupportedVersion];
    if (min == null || min.isEmpty) return false;
    final version = await _versionProvider();
    if (version == null) return false;
    _updateRequired = versionOlderThan(version, min);
    return _updateRequired!;
  }

  /// Pure comparison: dots-separated numeric segments; a missing
  /// segment counts as 0; any non-numeric segment treats the version
  /// as older (conservative forced-update default).
  static bool versionOlderThan(String version, String minimum) {
    final a = version.split('.');
    final b = minimum.split('.');
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final av = int.tryParse(i < a.length ? a[i] : '0');
      final bv = int.tryParse(i < b.length ? b[i] : '0');
      if (av == null || bv == null) return true;
      if (av != bv) return av < bv;
    }
    return false;
  }
}
