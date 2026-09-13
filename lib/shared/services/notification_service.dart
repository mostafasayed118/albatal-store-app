import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'logger.dart';

/// Notification opt-in persistence (feature-batch §12).
///
/// Consumer-side port (audit 2026-09-13): defined beside its only
/// consumer so the shared layer never imports a feature's data layer.
/// The SharedPreferences implementation lives in
/// `features/settings/data/notification_prefs_store.dart`.
abstract interface class NotificationPrefsStore {
  bool get orderNotificationsEnabled;
  bool get pushEnabled;

  void setOrderNotifications(bool enabled);
  void setPush(bool enabled);
}

/// Local notification port (feature-batch §12).
abstract interface class NotificationService {
  /// Idempotent plugin init + permission request. Fail-silent.
  Future<void> init();

  /// Shows a local notification when order notifications are opted in.
  /// Safe to call anywhere; no-ops on unsupported platforms.
  Future<void> showOrderNotification({
    required String title,
    required String body,
  });
}

/// `flutter_local_notifications` implementation. Channel
/// `order_status` (importance: default, sound: default). Every failure
/// degrades to a log line — notifications are advisory.
final class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPrefsStore? prefs,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _prefs = prefs;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPrefsStore? _prefs;
  bool _initialized = false;

  static const _androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: _androidInit),
      );
      _initialized = true;
    } on Exception catch (e, st) {
      Log.w('notifications init failed: $e');
      Log.d(st.toString());
    }
  }

  @override
  Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {
    if (_prefs != null && !_prefs.orderNotificationsEnabled) return;
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch % 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'order_status',
            'Order status',
            channelDescription: 'Order confirmation and status updates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } on Exception catch (e, st) {
      Log.w('notification show failed: $e');
      Log.d(st.toString());
    }
  }
}

/// No-op used by tests and platforms without a notification plugin.
class NoOpNotificationService implements NotificationService {
  const NoOpNotificationService();

  @override
  Future<void> init() async {}

  @override
  Future<void> showOrderNotification(
      {required String title, required String body}) async {}
}
