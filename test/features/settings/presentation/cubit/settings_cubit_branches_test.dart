import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_state.dart';
import 'package:al_batal_elite/shared/services/biometric_service.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _SettingsRepo implements SettingsRepository {
  _SettingsRepo({this.readResult, this.saveResult = const Success(null)});

  Result<AppSettings>? readResult;
  Result<void> saveResult;
  AppThemeMode? savedTheme;
  AppLocale? savedLocale;

  @override
  Future<Result<AppSettings>> read() async =>
      readResult ??
      const Success(AppSettings(
          themeMode: AppThemeMode.system, locale: AppLocale.english));

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) async {
    savedTheme = themeMode;
    return saveResult;
  }

  @override
  Future<Result<void>> saveLocale(AppLocale locale) async {
    savedLocale = locale;
    return saveResult;
  }
}

final class _Prefs extends Fake implements NotificationPrefsStore {
  bool orderEnabled = true;
  bool? written;

  @override
  bool get orderNotificationsEnabled => orderEnabled;

  @override
  void setOrderNotifications(bool value) => written = value;
}

final class _Notifications extends Fake implements NotificationService {
  bool permissionRequested = false;

  @override
  Future<void> requestPermission() async => permissionRequested = true;
}

final class _LockStore extends Fake implements AppLockPrefsStore {
  _LockStore({this.enabled = false});
  @override
  bool enabled;
  bool? written;

  @override
  void setEnabled(bool value) {
    enabled = value;
    written = value;
  }
}

final class _Biometrics extends Fake implements BiometricService {
  _Biometrics({
    this.canAuthenticateResult = true,
    this.authenticateResult = true,
    this.throwOnCanAuthenticate = false,
    this.throwOnAuthenticate = false,
  });

  final bool canAuthenticateResult;
  final bool authenticateResult;
  final bool throwOnCanAuthenticate;
  final bool throwOnAuthenticate;

  @override
  Future<bool> canAuthenticate() async {
    if (throwOnCanAuthenticate) throw Exception('plugin down');
    return canAuthenticateResult;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    if (throwOnAuthenticate) throw Exception('prompt down');
    return authenticateResult;
  }
}

void main() {
  test('load exposes notification and app-lock state when stores exist',
      () async {
    final cubit = SettingsCubit(
      _SettingsRepo(
          readResult: const Success(AppSettings(
              themeMode: AppThemeMode.dark, locale: AppLocale.arabic))),
      notificationPrefs: _Prefs(),
      appLockStore: _LockStore(enabled: true),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, SettingsStatus.ready);
    expect(cubit.state.themeMode, ThemeMode.dark);
    expect(cubit.state.locale, const Locale('ar'));
    expect(cubit.state.orderNotifications, isTrue);
    expect(cubit.state.appLockEnabled, isTrue);
  });

  test('load clears optional state when no stores are registered', () async {
    final cubit = SettingsCubit(_SettingsRepo());
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.orderNotifications, isNull);
    expect(cubit.state.appLockEnabled, isNull);
  });

  test('load surfaces a coded repository failure', () async {
    final cubit = SettingsCubit(_SettingsRepo(
        readResult: const Failure<AppSettings>(
            AppError('read failed', code: 'read_failed'))));
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, SettingsStatus.failure);
    expect(cubit.state.errorMessage, 'read failed');
    expect(cubit.state.errorCode, 'read_failed');
  });

  test('toggleOrderNotifications is a no-op without a prefs store', () async {
    final cubit = SettingsCubit(_SettingsRepo());
    addTearDown(cubit.close);

    cubit.toggleOrderNotifications(true);

    expect(cubit.state.orderNotifications, isNull);
  });

  test('toggleOrderNotifications persists and requests permission on opt-in',
      () async {
    final prefs = _Prefs();
    final notifications = _Notifications();
    final cubit = SettingsCubit(
      _SettingsRepo(),
      notificationPrefs: prefs,
      notifications: notifications,
    );
    addTearDown(cubit.close);

    cubit.toggleOrderNotifications(true);

    expect(prefs.written, isTrue);
    expect(notifications.permissionRequested, isTrue);
    expect(cubit.state.orderNotifications, isTrue);
  });

  test('setAppLock returns false when no store is registered', () async {
    final cubit = SettingsCubit(_SettingsRepo());
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isFalse);
  });

  test('setAppLock refuses to arm without an authenticator', () async {
    final store = _LockStore();
    final cubit = SettingsCubit(_SettingsRepo(), appLockStore: store);
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isFalse);
    expect(store.written, isNull);
  });

  test('setAppLock can disarm without an authenticator', () async {
    final store = _LockStore(enabled: true);
    final cubit = SettingsCubit(_SettingsRepo(), appLockStore: store);
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(false, reason: 'unlock'), isTrue);
    expect(store.written, isFalse);
    expect(cubit.state.appLockEnabled, isFalse);
  });

  test('setAppLock fails closed when the capability probe throws', () async {
    final store = _LockStore();
    final cubit = SettingsCubit(
      _SettingsRepo(),
      appLockStore: store,
      biometrics: _Biometrics(throwOnCanAuthenticate: true),
    );
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isFalse);
    expect(store.written, isNull);
  });

  test('setAppLock fails closed when the device cannot authenticate', () async {
    final cubit = SettingsCubit(
      _SettingsRepo(),
      appLockStore: _LockStore(),
      biometrics: _Biometrics(canAuthenticateResult: false),
    );
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isFalse);
  });

  test('setAppLock fails closed when authentication throws', () async {
    final store = _LockStore();
    final cubit = SettingsCubit(
      _SettingsRepo(),
      appLockStore: store,
      biometrics: _Biometrics(throwOnAuthenticate: true),
    );
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isFalse);
    expect(store.written, isNull);
  });

  test('setAppLock fails closed when the user does not confirm', () async {
    final cubit = SettingsCubit(
      _SettingsRepo(),
      appLockStore: _LockStore(),
      biometrics: _Biometrics(authenticateResult: false),
    );
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isFalse);
  });

  test('setAppLock persists after a confirmed authentication', () async {
    final store = _LockStore();
    final cubit = SettingsCubit(
      _SettingsRepo(),
      appLockStore: store,
      biometrics: _Biometrics(),
    );
    addTearDown(cubit.close);

    expect(await cubit.setAppLock(true, reason: 'unlock'), isTrue);
    expect(store.written, isTrue);
    expect(cubit.state.appLockEnabled, isTrue);
  });

  test('changeThemeMode saves and returns to ready', () async {
    final repo = _SettingsRepo();
    final cubit = SettingsCubit(repo);
    addTearDown(cubit.close);

    await cubit.changeThemeMode(ThemeMode.dark);

    expect(repo.savedTheme, AppThemeMode.dark);
    expect(cubit.state.status, SettingsStatus.ready);
    expect(cubit.state.themeMode, ThemeMode.dark);
  });

  test('changeLocale maps the locale and surfaces save failures', () async {
    final repo = _SettingsRepo(
      saveResult: const Failure<void>(
          AppError('Unable to save app preferences.', code: 'save_failed')),
    );
    final cubit = SettingsCubit(repo);
    addTearDown(cubit.close);

    await cubit.changeLocale(const Locale('ar'));

    expect(repo.savedLocale, AppLocale.arabic);
    expect(cubit.state.status, SettingsStatus.failure);
    expect(cubit.state.errorCode, 'save_failed');
  });
}
