import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Per-product back-in-stock alert opt-ins (task #5, client-side slice).
///
/// Follows the same consumer-side port pattern as
/// [NotificationPrefsStore]: the port lives beside its consumer so the
/// shared layer never imports a feature's data layer. The
/// SharedPreferences implementation lives in
/// `features/storefront/data/back_in_stock_alert_store.dart`.
///
/// The per-product toggle IS the opt-in — alerts are deliberately NOT
/// gated on [NotificationPrefsStore.orderNotificationsEnabled], which is
/// the order-status master switch.
abstract interface class BackInStockAlertStore {
  Set<String> get watchedProductIds;
  bool isWatched(String productId);
  void setWatched(String productId, bool enabled);
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

  /// Shows a local back-in-stock alert (task #5). The caller guarantees
  /// the product toggle is on; [title]/[body] are already localized.
  /// Safe to call anywhere; no-ops on unsupported platforms.
  Future<void> showBackInStockNotification({
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
    Future<void> Function()? requestNotificationPermission,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _prefs = prefs,
        _requestNotificationPermission =
            requestNotificationPermission ?? _requestPermission;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPrefsStore? _prefs;
  final Future<void> Function() _requestNotificationPermission;
  bool _initialized = false;

  static const _androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  static Future<void> _requestPermission() async {
    await Permission.notification.request();
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: _androidInit),
      );
      _initialized = true;
      await _requestNotificationPermission();
    } on Exception catch (e, st) {
      Log.w('notifications init failed.', error: e);
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
      Log.w('notification show failed.', error: e);
      Log.d(st.toString());
    }
  }

  @override
  Future<void> showBackInStockNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch % 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'back_in_stock',
            'Stock alerts',
            channelDescription: 'Wishlist items available again',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } on Exception catch (e, st) {
      Log.w('back-in-stock notification failed.', error: e);
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

  @override
  Future<void> showBackInStockNotification(
      {required String title, required String body}) async {}
}
