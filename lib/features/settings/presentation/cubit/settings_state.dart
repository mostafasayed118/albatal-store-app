import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SettingsStatus { initial, loading, ready, saving, failure }

final class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.errorMessage,
  });

  final SettingsStatus status;
  final ThemeMode themeMode;
  final Locale locale;
  final String? errorMessage;

  SettingsState copyWith({
    SettingsStatus? status,
    ThemeMode? themeMode,
    Locale? locale,
    String? errorMessage,
    bool clearError = false,
  }) =>
      SettingsState(
        status: status ?? this.status,
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, themeMode, locale, errorMessage];
}
