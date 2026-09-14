import 'package:al_batal_elite/shared/services/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFetcher implements RemoteConfigFetcher {
  _FakeFetcher(this.values);
  Map<String, String> values;
  int calls = 0;

  @override
  Future<Map<String, String>> fetch() async {
    calls++;
    return values;
  }
}

class _FailingFetcher implements RemoteConfigFetcher {
  @override
  Future<Map<String, String>> fetch() async => throw Exception('offline');
}

/// Malformed payload fetcher that throws a [TypeError] (an Error, not
/// an Exception) — mirrors the unchecked-cast hazard fixed in
/// SupabaseRemoteConfigFetcher (audit 2026-09-14).
class _ThrowingTypeErrorFetcher implements RemoteConfigFetcher {
  @override
  Future<Map<String, String>> fetch() async {
    // Mirrors the unchecked-cast hazard fixed in
    // SupabaseRemoteConfigFetcher: a malformed row throws a TypeError
    // (an Error, not an Exception) during iteration.
    final rows = <Object>['not-a-map'];
    final map = <String, String>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }
}

void main() {
  group('RemoteConfigService (§13)', () {
    test('defaults when fetch fails (app must not boot-block)', () async {
      final service = RemoteConfigService(fetcher: _FailingFetcher());
      await service.refresh();
      expect(service.maintenanceMode, isFalse);
      expect(await service.updateRequired(), isFalse);
    });

    test('never throws when the fetcher raises an Error (TypeError)',
        () async {
      final service = RemoteConfigService(fetcher: _ThrowingTypeErrorFetcher());
      await service.refresh();
      expect(service.maintenanceMode, isFalse);
      expect(await service.updateRequired(), isFalse);
    });

    test('reads maintenance mode from the backend', () async {
      final fetcher =
          _FakeFetcher({RemoteConfigService.keyMaintenanceMode: 'true'});
      final service = RemoteConfigService(fetcher: fetcher);
      await service.refresh();
      expect(service.maintenanceMode, isTrue);
    });

    test('caches within the TTL and refetches when forced', () async {
      final fetcher = _FakeFetcher({});
      final service = RemoteConfigService(
        fetcher: fetcher,
        ttl: const Duration(minutes: 10),
      );
      await service.refresh();
      await service.refresh(); // within TTL: no extra call
      expect(fetcher.calls, 1);
      await service.refresh(force: true);
      expect(fetcher.calls, 2);
    });

    test('versionOlderThan compares numeric segments', () {
      expect(RemoteConfigService.versionOlderThan('1.2.0', '1.2.1'), isTrue);
      expect(RemoteConfigService.versionOlderThan('1.3.0', '1.2.9'), isFalse);
      expect(RemoteConfigService.versionOlderThan('1.2', '1.2.0'), isFalse);
      expect(RemoteConfigService.versionOlderThan('0.9.9', '1.0.0'), isTrue);
      // non-numeric → conservative older
      expect(
          RemoteConfigService.versionOlderThan('dev-build', '1.0.0'), isTrue);
    });

    test('updateRequired triggers below the minimum version', () async {
      final fetcher =
          _FakeFetcher({RemoteConfigService.keyMinSupportedVersion: '2.0.0'});
      final service = RemoteConfigService(
        fetcher: fetcher,
        versionProvider: () async => '1.5.0',
      );
      await service.refresh();
      expect(await service.updateRequired(), isTrue);
    });
  });
}
