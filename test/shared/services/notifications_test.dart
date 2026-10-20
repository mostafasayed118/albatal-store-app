import 'package:al_batal_elite/features/settings/data/notification_prefs_store.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _RecordingService implements NotificationService {
  _RecordingService(this.prefs);
  final NotificationPrefsStore prefs;
  int shown = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {
    // Gate lives in the service contract: opted-out users see nothing.
    if (!prefs.orderNotificationsEnabled) return;
    shown++;
  }

  @override
  Future<void> showBackInStockNotification({
    required String title,
    required String body,
  }) async {
    shown++;
  }
}

class _FakePushSdk implements PushSdk {
  final List<String> calls = <String>[];

  @override
  Future<void> initialize(String appId) async {
    calls.add('initialize:$appId');
  }

  @override
  Future<void> login(String externalId) async {
    calls.add('login:$externalId');
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  });

  group('NotificationPrefsStore (§12)', () {
    test('order notifications default to enabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs =
          PrefsNotificationStore(await SharedPreferences.getInstance());
      expect(prefs.orderNotificationsEnabled, isTrue);
      expect(prefs.pushEnabled, isFalse);
    });

    test('toggles persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs =
          PrefsNotificationStore(await SharedPreferences.getInstance());
      prefs.setOrderNotifications(false);
      prefs.setPush(true);
      expect(prefs.orderNotificationsEnabled, isFalse);
      expect(prefs.pushEnabled, isTrue);
    });
  });

  group('local notification gating (§12)', () {
    test('opted-in users receive the notification', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs =
          PrefsNotificationStore(await SharedPreferences.getInstance());
      final service = _RecordingService(prefs);
      await service.showOrderNotification(title: 't', body: 'b');
      expect(service.shown, 1);
    });

    test('opted-out users receive nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs =
          PrefsNotificationStore(await SharedPreferences.getInstance());
      prefs.setOrderNotifications(false);
      final service = _RecordingService(prefs);
      await service.showOrderNotification(title: 't', body: 'b');
      expect(service.shown, 0);
    });
  });

  test('init never prompts; requestPermission is user-initiated', () async {
    final plugin = _MockNotificationsPlugin();
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => true);
    var requests = 0;
    final service = LocalNotificationService(
      plugin: plugin,
      requestNotificationPermission: () async {
        requests++;
      },
    );

    await service.init();
    await service.init();
    expect(requests, 0);

    await service.requestPermission();
    await service.requestPermission();
    expect(requests, 2);
  });

  group('PushService (§12)', () {
    test('construction is safe without configuration', () {
      // EnvConfig.onesignalAppId is empty in tests: init() must be a
      // no-op that neither throws nor touches the network.
      expect(OneSignalPushService(), isA<PushService>());
    });

    test('empty app id never touches the SDK', () async {
      final sdk = _FakePushSdk();
      final service = OneSignalPushService(sdk: sdk, appId: '');

      await service.init();
      await service.login('user-1');
      await service.logout();

      expect(sdk.calls, isEmpty);
    });

    test('init, login and logout forward to the SDK once configured', () async {
      final sdk = _FakePushSdk();
      final service = OneSignalPushService(sdk: sdk, appId: 'app-1');

      await service.init();
      await service.init();
      await service.login('user-1');
      await service.logout();

      expect(sdk.calls, ['initialize:app-1', 'login:user-1', 'logout']);
    });
  });
}
