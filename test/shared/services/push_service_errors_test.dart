import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControllablePushSdk implements PushSdk {
  final List<String> calls = <String>[];
  bool throwOnInit = false;
  bool throwOnLogin = false;
  bool throwOnLogout = false;
  bool permissionGranted = true;
  String? currentSubscriptionId;
  final List<void Function(String?)> observers = <void Function(String?)>[];

  @override
  Future<void> initialize(String appId) async {
    calls.add('initialize:$appId');
    if (throwOnInit) throw Exception('init failed');
  }

  @override
  Future<void> login(String externalId) async {
    calls.add('login:$externalId');
    if (throwOnLogin) throw Exception('login failed');
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    if (throwOnLogout) throw Exception('logout failed');
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permissionGranted;
  }

  @override
  String? get subscriptionId => currentSubscriptionId;

  @override
  void addSubscriptionObserver(void Function(String? id) listener) {
    observers.add(listener);
  }

  @override
  void removeSubscriptionObserver(void Function(String? id) listener) {
    observers.remove(listener);
  }
}

void main() {
  test('a failed init leaves the service uninitialized and login is a no-op',
      () async {
    final sdk = _ControllablePushSdk()..throwOnInit = true;
    final service = OneSignalPushService(sdk: sdk, appId: 'app-1');

    await service.init();
    await service.login('user-1');

    // A failed init is retried by login, but the SDK login is never reached.
    expect(sdk.calls, ['initialize:app-1', 'initialize:app-1']);
  });

  test('concurrent init calls share one SDK initialization', () async {
    final sdk = _ControllablePushSdk();
    final service = OneSignalPushService(sdk: sdk, appId: 'app-1');

    await Future.wait([service.init(), service.init(), service.login('u1')]);

    expect(sdk.calls.where((c) => c.startsWith('initialize:')), hasLength(1));
    expect(sdk.calls, contains('login:u1'));
  });

  test('login and logout failures are swallowed', () async {
    final sdk = _ControllablePushSdk()
      ..throwOnLogin = true
      ..throwOnLogout = true;
    final service = OneSignalPushService(sdk: sdk, appId: 'app-1');

    await service.init();
    await expectLater(service.login('user-1'), completes);
    await expectLater(service.logout(), completes);

    expect(sdk.calls, ['initialize:app-1', 'login:user-1', 'logout']);
  });

  test('empty app id keeps login and logout off the SDK', () async {
    final sdk = _ControllablePushSdk();
    final service = OneSignalPushService(sdk: sdk, appId: '');

    await service.login('user-1');
    await service.logout();

    expect(sdk.calls, isEmpty);
  });
}
