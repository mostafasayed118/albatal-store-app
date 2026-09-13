import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SettingsStatus { initial, loading, ready, saving, failure }

final class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.errorMessage,
    this.orderNotifications,
  });

  final SettingsStatus status;
  final ThemeMode themeMode;
  final Locale locale;
  final String? errorMessage;

  /// §12 order-notification opt-in. Null = no notification prefs store
  /// was registered at the composition root (tests / unsupported
  /// platform) and the settings tile stays hidden.
  final bool? orderNotifications;

  SettingsState copyWith({
    SettingsStatus? status,
    ThemeMode? themeMode,
    Locale? locale,
    String? errorMessage,
    bool clearError = false,
    bool? orderNotifications,
    bool clearOrderNotifications = false,
  }) =>
      SettingsState(
        status: status ?? this.status,
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        orderNotifications: clearOrderNotifications
            ? null
            : orderNotifications ?? this.orderNotifications,
      );

  @override
  List<Object?> get props =>
      [status, themeMode, locale, errorMessage, orderNotifications];
}
