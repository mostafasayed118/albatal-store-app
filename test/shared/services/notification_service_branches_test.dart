import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _FakePrefs implements NotificationPrefsStore {
  _FakePrefs({this.orderEnabled = true});

  bool orderEnabled;

  @override
  bool get orderNotificationsEnabled => orderEnabled;

  @override
  bool get pushEnabled => false;

  @override
  void setOrderNotifications(bool enabled) => orderEnabled = enabled;

  @override
  void setPush(bool enabled) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNotificationsPlugin plugin;

  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(0);
    registerFallbackValue('');
  });

  setUp(() {
    plugin = _MockNotificationsPlugin();
  });

  void stubInitSuccess() {
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => true);
  }

  void stubShowSuccess() {
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
  }

  test('init is idempotent after success', () async {
    stubInitSuccess();
    final service = LocalNotificationService(plugin: plugin);

    await service.init();
    await service.init();

    verify(() => plugin.initialize(settings: any(named: 'settings'))).called(1);
  });

  test('init failure is swallowed and leaves the service uninitialized',
      () async {
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenThrow(Exception('plugin unavailable'));
    stubShowSuccess();
    final service = LocalNotificationService(plugin: plugin);

    await service.init();
    await service.showOrderNotification(title: 't', body: 'b');

    verifyNever(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('requestPermission delegates and swallows failures', () async {
    var calls = 0;
    final service = LocalNotificationService(
      plugin: plugin,
      requestNotificationPermission: () async => calls++,
    );

    await service.requestPermission();
    expect(calls, 1);

    final failing = LocalNotificationService(
      plugin: plugin,
      requestNotificationPermission: () async =>
          throw Exception('permission denied'),
    );
    await expectLater(failing.requestPermission(), completes);
  });

  test('the default permission request degrades without a platform channel',
      () async {
    final service = LocalNotificationService(plugin: plugin);

    await expectLater(service.requestPermission(), completes);
  });

  test('order notifications are skipped when the user opted out', () async {
    stubInitSuccess();
    stubShowSuccess();
    final service = LocalNotificationService(
      plugin: plugin,
      prefs: _FakePrefs(orderEnabled: false),
    );

    await service.showOrderNotification(title: 't', body: 'b');
    await service.init();
    await service.showOrderNotification(title: 't', body: 'b');

    verifyNever(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    );
  });

  test('order notification initializes lazily and shows with the channel',
      () async {
    stubInitSuccess();
    stubShowSuccess();
    final service = LocalNotificationService(
      plugin: plugin,
      prefs: _FakePrefs(),
    );

    await service.showOrderNotification(title: 'Order ready', body: 'Pick up');

    final details = verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: 'Order ready',
        body: 'Pick up',
        notificationDetails: captureAny(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).captured.single as NotificationDetails;
    expect(details.android!.channelId, 'order_status');
  });

  test('show failures are swallowed', () async {
    stubInitSuccess();
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenThrow(Exception('no channel'));

    final service = LocalNotificationService(plugin: plugin);
    expect(
      () => service.showOrderNotification(title: 't', body: 'b'),
      returnsNormally,
    );
    expect(
      () => service.showBackInStockNotification(title: 't', body: 'b'),
      returnsNormally,
    );
  });

  test('back-in-stock notification initializes lazily and shows', () async {
    stubInitSuccess();
    stubShowSuccess();
    final service = LocalNotificationService(plugin: plugin);

    await service.showBackInStockNotification(
      title: 'Back in stock',
      body: 'Product available',
    );

    final details = verify(
      () => plugin.show(
        id: any(named: 'id'),
        title: 'Back in stock',
        body: 'Product available',
        notificationDetails: captureAny(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).captured.single as NotificationDetails;
    expect(details.android!.channelId, 'back_in_stock');
  });
}
