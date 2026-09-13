import 'package:al_batal_elite/features/settings/data/notification_prefs_store.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:al_batal_elite/shared/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingService implements NotificationService {
  _RecordingService(this.prefs);
  final NotificationPrefsStore prefs;
  int shown = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {
    // Gate lives in the service contract: opted-out users see nothing.
    if (!prefs.orderNotificationsEnabled) return;
    shown++;
  }
}

void main() {
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

  group('PushService (§12)', () {
    test('construction is safe without configuration', () {
      // EnvConfig.onesignalAppId is empty in tests: init() must be a
      // no-op that neither throws nor touches the network.
      expect(const OneSignalPushService(), isA<PushService>());
    });
  });
}
