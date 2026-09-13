import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/services/notification_service.dart';

const _kOrderNotifications = 'notifications_order_enabled_v1';
const _kPush = 'notifications_push_enabled_v1';

/// SharedPreferences-backed implementation of the notification opt-in
/// port defined beside [NotificationService] (consumer-side port — the
/// shared layer never imports this file, audit 2026-09-13). The
/// settings feature exposes the toggle through [SettingsCubit].
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
