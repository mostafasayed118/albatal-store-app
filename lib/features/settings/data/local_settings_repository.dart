import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../shared/extensions/iterable_x.dart';
import '../domain/repositories/settings_repository.dart';

final class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._preferences);

  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'locale';
  static const _supportedLanguageCodes = {'en', 'ar'};

  final SharedPreferences _preferences;

  @override
  Future<Result<AppSettings>> read() async {
    try {
      final savedTheme = _preferences.getString(_themeModeKey);
      final savedLanguage = _preferences.getString(_localeKey);
      final themeMode = ThemeMode.values.where((mode) => mode.name == savedTheme).firstOrNull ?? ThemeMode.system;
      final languageCode = _supportedLanguageCodes.contains(savedLanguage) ? savedLanguage! : 'en';
      return Success(AppSettings(themeMode: themeMode, locale: Locale(languageCode)));
    } catch (error) {
      return Failure(AppError('Unable to read app preferences.', cause: error));
    }
  }

  @override
  Future<Result<void>> saveThemeMode(ThemeMode themeMode) => _write(
        () => _preferences.setString(_themeModeKey, themeMode.name),
      );

  @override
  Future<Result<void>> saveLocale(Locale locale) {
    if (!_supportedLanguageCodes.contains(locale.languageCode)) {
      return Future.value(const Failure(AppError('Unsupported language.')));
    }
    return _write(() => _preferences.setString(_localeKey, locale.languageCode));
  }

  Future<Result<void>> _write(Future<bool> Function() operation) async {
    try {
      final didPersist = await operation();
      return didPersist
          ? const Success(null)
          : const Failure(AppError('Unable to save app preferences.'));
    } catch (error) {
      return Failure(AppError('Unable to save app preferences.', cause: error));
    }
  }
}
