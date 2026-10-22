import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The production `OneSignalSdk` seam is otherwise only exercised
/// on-device. Mock the OneSignal channels so its initialize/login/logout
/// delegation and debug-log level wiring run in the VM.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channels = <String>[
    'OneSignal',
    'OneSignal#debug',
    'OneSignal#inappmessages',
    'OneSignal#user',
    'OneSignal#pushsubscription',
    'OneSignal#notifications',
  ];

  final calls = <MethodCall>[];

  setUpAll(() {
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add(call);
        if (call.method == 'OneSignal#permission') return true;
        return null;
      });
    }
  });

  tearDownAll(() {
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  setUp(calls.clear);

  test('initialize sets the debug level in debug builds and inits the SDK',
      () async {
    await OneSignalSdk().initialize('app-1');

    expect(
      calls,
      contains(predicate<MethodCall>(
          (c) => c.method == 'OneSignal#setLogLevel' && c.arguments is Map)),
    );
    expect(
      calls,
      contains(predicate<MethodCall>((c) =>
          c.method == 'OneSignal#initialize' &&
          (c.arguments as Map)['appId'] == 'app-1')),
    );
  });

  test('login and logout forward the external id / call', () async {
    await OneSignalSdk().login('user-42');
    await OneSignalSdk().logout();

    expect(
      calls,
      contains(predicate<MethodCall>((c) =>
          c.method == 'OneSignal#login' &&
          (c.arguments as Map)['externalId'] == 'user-42')),
    );
    expect(
      calls,
      contains(predicate<MethodCall>((c) => c.method == 'OneSignal#logout')),
    );
  });
}
