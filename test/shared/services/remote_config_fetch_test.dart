import 'package:al_batal_elite/shared/services/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_admin_fakes.dart';

class _StaticFetcher implements RemoteConfigFetcher {
  _StaticFetcher(this.values);
  final Map<String, String> values;

  @override
  Future<Map<String, String>> fetch() async => values;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseRemoteConfigFetcher', () {
    late MockSupabaseClient client;
    late MockSupabaseQueryBuilder builder;

    setUp(() {
      client = MockSupabaseClient();
      builder = MockSupabaseQueryBuilder();
      when(() => client.from('app_config')).thenAnswer((_) => builder);
    });

    test('returns only string key/value rows', () async {
      when(() => builder.select('key, value')).thenAnswer(
        (_) => FakeFilterBuilder<PostgrestList>([
          {'key': 'maintenance_mode', 'value': 'true'},
          {'key': 'max_retries', 'value': 3},
          {'key': 7, 'value': 'skip'},
        ]),
      );

      final config = await SupabaseRemoteConfigFetcher(client: client).fetch();

      expect(config, {'maintenance_mode': 'true'});
    });
  });

  group('RemoteConfigService version gate', () {
    test('a failing platform version lookup disables the gate', () async {
      // No PackageInfo mock and no version provider: the plugin channel is
      // absent under `flutter test`, so the lookup throws and is swallowed.
      final service = RemoteConfigService(
        fetcher: _StaticFetcher({
          RemoteConfigService.keyMinSupportedVersion: '2.0.0',
        }),
      );
      await service.refresh();

      expect(await service.updateRequired(), isFalse);
    });

    test('uses PackageInfo when no version provider is injected', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Al Batal',
        packageName: 'com.example.albatal',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final service = RemoteConfigService(
        fetcher: _StaticFetcher({
          RemoteConfigService.keyMinSupportedVersion: '2.0.0',
        }),
      );

      await service.refresh();

      expect(await service.updateRequired(), isTrue);
    });

    test('no configured minimum never forces an update', () async {
      final service = RemoteConfigService(fetcher: _StaticFetcher({}));

      await service.refresh();

      expect(await service.updateRequired(), isFalse);
    });

    test('an unavailable version never forces an update', () async {
      final service = RemoteConfigService(
        fetcher: _StaticFetcher({
          RemoteConfigService.keyMinSupportedVersion: '9.9.9',
        }),
        versionProvider: () async => null,
      );

      await service.refresh();

      expect(await service.updateRequired(), isFalse);
    });
  });
}
