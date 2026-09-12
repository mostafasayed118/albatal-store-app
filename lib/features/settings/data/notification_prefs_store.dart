import 'package:shared_preferences/shared_preferences.dart';

/// Notification opt-in persistence (feature-batch §12).
abstract interface class NotificationPrefsStore {
  bool get orderNotificationsEnabled;
  bool get pushEnabled;

  void setOrderNotifications(bool enabled);
  void setPush(bool enabled);
}

const _kOrderNotifications = 'notifications_order_enabled_v1';
const _kPush = 'notifications_push_enabled_v1';

final class PrefsNotificationStore implements NotificationPrefsStore {
  PrefsNotificationStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool get orderNotificationsEnabled =>
      _prefs.getBool(_kOrderNotifications) ?? true;

  @override
  bool get pushEnabled => _prefs.getBool(_kPush) ?? false;

  @override
  void setOrderNotifications(bool enabled) =>
      _prefs.setBool(_kOrderNotifications, enabled);

  @override
  void setPush(bool enabled) => _prefs.setBool(_kPush, enabled);
}
