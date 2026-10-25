import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/shared/services/env_config.dart';
import 'package:al_batal_elite/shared/services/oauth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _MockSupabaseClient extends Mock implements sb.SupabaseClient {}

class _MockGoTrueClient extends Mock implements sb.GoTrueClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late bool launchResult;

  setUpAll(() {
    registerFallbackValue(sb.OAuthProvider.google);
  });

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    launchResult = true;
    when(() => client.auth).thenReturn(auth);
    when(() => auth.getOAuthSignInUrl(
          provider: any(named: 'provider'),
          redirectTo: any(named: 'redirectTo'),
          scopes: any(named: 'scopes'),
          queryParams: any(named: 'queryParams'),
        )).thenAnswer(
      (inv) async => sb.OAuthResponse(
        provider: inv.namedArguments[#provider] as sb.OAuthProvider,
        url: 'https://auth.test/authorize',
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
      if (call.method == 'launch') return launchResult;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  test('maps both providers and returns success when the browser opens',
      () async {
    final service = SupabaseOAuthService(client: client);

    final google = await service.signIn(OAuthProvider.google);
    final apple = await service.signIn(OAuthProvider.apple);

    expect(google, isA<Success<String>>());
    expect((google as Success<String>).value, 'ok');
    expect(apple, isA<Success<String>>());
  });

  test('passes the configured redirect to the provider url', () async {
    final service = SupabaseOAuthService(client: client);

    await service.signIn(OAuthProvider.google);

    verify(() => auth.getOAuthSignInUrl(
          provider: any(named: 'provider'),
          redirectTo: EnvConfig.oauthRedirect,
          scopes: any(named: 'scopes'),
          queryParams: any(named: 'queryParams'),
        )).called(1);
    expect(EnvConfig.oauthRedirect, 'albatal://login-callback');
  });

  test('returns the cancelled code when the browser does not open', () async {
    launchResult = false;
    final service = SupabaseOAuthService(client: client);

    final result = await service.signIn(OAuthProvider.google);

    expect(result, isA<Failure<String>>());
    expect((result as Failure<String>).error.message, kOAuthCancelled);
    expect(result.error.code, kOAuthCancelled);
  });

  test('returns the unavailable code when the provider throws', () async {
    when(() => auth.getOAuthSignInUrl(
          provider: any(named: 'provider'),
          redirectTo: any(named: 'redirectTo'),
          scopes: any(named: 'scopes'),
          queryParams: any(named: 'queryParams'),
        )).thenThrow(const sb.AuthException('provider disabled'));
    final service = SupabaseOAuthService(client: client);

    final result = await service.signIn(OAuthProvider.google);

    expect(result, isA<Failure<String>>());
    expect((result as Failure<String>).error.message, kOAuthUnavailable);
    expect(result.error.code, kOAuthUnavailable);
  });
}
