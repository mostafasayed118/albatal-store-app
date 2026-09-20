import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/biometric_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../domain/repositories/settings_repository.dart';
import 'settings_state.dart';

/// Presentation-layer settings controller.
///
/// This is the only boundary that knows about Material's `ThemeMode`:
/// it maps the framework-free [AppThemeMode]/[AppLocale] domain values
/// to/from the Material/`dart:ui` types the UI consumes. The domain and
/// data layers must never import Flutter (audit residual fix).
///
/// §12 notification opt-in flows through here too: the page renders
/// the toggle from [SettingsState.orderNotifications] (null = store
/// not registered, tile hidden) instead of probing the DI container
/// during build (audit 2026-09-13).
///
/// §15 biometric app-lock opt-in follows the same shape via
/// [SettingsState.appLockEnabled] and [setAppLock]. It previously had NO
/// caller at all — `AppLockPrefsStore.setEnabled` was never invoked, so the
/// app lock could not be enabled and [AppLockGate] never armed.
final class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    this._repository, {
    NotificationPrefsStore? notificationPrefs,
    BiometricService? biometrics,
    AppLockPrefsStore? appLockStore,
  })  : _notificationPrefs = notificationPrefs,
        _biometrics = biometrics,
        _appLockStore = appLockStore,
        super(const SettingsState());

  final SettingsRepository _repository;
  final NotificationPrefsStore? _notificationPrefs;
  final BiometricService? _biometrics;
  final AppLockPrefsStore? _appLockStore;

  Future<void> load() async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));
    final result = await _repository.read();
    if (isClosed) return;
    result.when(
      success: (settings) => emit(state.copyWith(
        status: SettingsStatus.ready,
        themeMode: _toMaterialThemeMode(settings.themeMode),
        locale: Locale(settings.locale.languageCode),
        orderNotifications:
            _notificationPrefs?.orderNotificationsEnabled ?? false,
        clearOrderNotifications: _notificationPrefs == null,
        appLockEnabled: _appLockStore?.enabled ?? false,
        clearAppLock: _appLockStore == null,
      )),
      failure: (error) => emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: error.message,
        errorCode: error.code,
      )),
    );
  }

  /// §12: persist the order-notification opt-in optimistically. The
  /// store write is synchronous prefs I/O, so no failure path exists.
  void toggleOrderNotifications(bool enabled) {
    final prefs = _notificationPrefs;
    if (prefs == null) return;
    prefs.setOrderNotifications(enabled);
    emit(state.copyWith(orderNotifications: enabled));
  }

  /// §15: arms or disarms the biometric app lock.
  ///
  /// Arms only when the device can actually authenticate AND the user
  /// confirms their identity — a stray tap must not arm a lock the owner
  /// cannot satisfy. Disarming authenticates too, so someone holding the
  /// unlocked device cannot simply switch the protection off.
  ///
  /// Returns true when the requested value was persisted. A false return
  /// means "device cannot authenticate / user did not confirm / no store"
  /// and the caller surfaces it (the toggle must not silently snap back).
  Future<bool> setAppLock(bool enabled, {required String reason}) async {
    final store = _appLockStore;
    if (store == null) return false;
    final biometrics = _biometrics;
    if (biometrics == null) {
      // No authenticator wired but the store present: only a disarm can be
      // honoured (disarming cannot lock the owner out, arming could).
      if (enabled) return false;
      store.setEnabled(false);
      if (isClosed) return true;
      emit(state.copyWith(appLockEnabled: false));
      return true;
    }

    var canAuthenticate = false;
    try {
      canAuthenticate = await biometrics.canAuthenticate();
    } on Exception {
      canAuthenticate = false;
    }
    if (isClosed) return false;
    if (!canAuthenticate) return false;

    var confirmed = false;
    try {
      confirmed = await biometrics.authenticate(reason: reason);
    } on Exception {
      confirmed = false;
    }
    if (isClosed) return false;
    if (!confirmed) return false;

    store.setEnabled(enabled);
    emit(state.copyWith(appLockEnabled: enabled));
    return true;
  }

  Future<void> changeThemeMode(ThemeMode themeMode) => _save(
        optimistic: state.copyWith(themeMode: themeMode),
        persist: () =>
            _repository.saveThemeMode(_fromMaterialThemeMode(themeMode)),
      );

  Future<void> changeLocale(Locale locale) => _save(
        optimistic: state.copyWith(locale: locale),
        persist: () => _repository.saveLocale(AppLocale.fromLanguageCode(
          locale.languageCode,
        )),
      );

  Future<void> _save({
    required SettingsState optimistic,
    required Future<dynamic> Function() persist,
  }) async {
    emit(optimistic.copyWith(status: SettingsStatus.saving, clearError: true));
    final result = await persist();
    result.when(
      success: (_) => emit(state.copyWith(status: SettingsStatus.ready)),
      failure: (error) => emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: error.message,
        errorCode: error.code,
      )),
    );
  }

  static ThemeMode _toMaterialThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static AppThemeMode _fromMaterialThemeMode(ThemeMode mode) => switch (mode) {
        ThemeMode.system => AppThemeMode.system,
        ThemeMode.light => AppThemeMode.light,
        ThemeMode.dark => AppThemeMode.dark,
      };
}
