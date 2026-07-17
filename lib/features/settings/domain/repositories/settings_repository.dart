import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> read();
  Future<Result<void>> saveThemeMode(ThemeMode themeMode);
  Future<Result<void>> saveLocale(Locale locale);
}

final class AppSettings {
  const AppSettings({required this.themeMode, required this.locale});

  final ThemeMode themeMode;
  final Locale locale;

  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    locale: Locale('en'),
  );
}
