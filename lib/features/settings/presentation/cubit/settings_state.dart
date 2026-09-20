import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SettingsStatus { initial, loading, ready, saving, failure }

final class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.errorMessage,
    this.errorCode,
    this.orderNotifications,
    this.appLockEnabled,
  });

  final SettingsStatus status;
  final ThemeMode themeMode;
  final Locale locale;
  final String? errorMessage;

  /// Machine-readable class of [errorMessage]; the page localizes on this
  /// (audit 2026-09-19, sweep part 32).
  final String? errorCode;

  /// §12 order-notification opt-in. Null = no notification prefs store
  /// was registered at the composition root (tests / unsupported
  /// platform) and the settings tile stays hidden.
  final bool? orderNotifications;

  /// §15 biometric app-lock opt-in. Null = no app-lock store was
  /// registered at the composition root, so the settings tile stays
  /// hidden (same convention as [orderNotifications]).
  final bool? appLockEnabled;

  SettingsState copyWith({
    SettingsStatus? status,
    ThemeMode? themeMode,
    Locale? locale,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    bool? orderNotifications,
    bool clearOrderNotifications = false,
    bool? appLockEnabled,
    bool clearAppLock = false,
  }) =>
      SettingsState(
        status: status ?? this.status,
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        errorCode: clearError ? null : errorCode ?? this.errorCode,
        orderNotifications: clearOrderNotifications
            ? null
            : orderNotifications ?? this.orderNotifications,
        appLockEnabled:
            clearAppLock ? null : appLockEnabled ?? this.appLockEnabled,
      );

  @override
  List<Object?> get props => [
        status,
        themeMode,
        locale,
        errorMessage,
        errorCode,
        orderNotifications,
        appLockEnabled,
      ];
}
