import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/settings_repository.dart';

/// Persists preferences as plain strings — no Flutter types here either.
///
/// Stored values are unchanged from before the domain purification
/// (`system`/`light`/`dark`, `en`/`ar`), so existing user preferences
/// remain valid with no migration.
final class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._preferences);

  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'locale';

  final SharedPreferences _preferences;

  @override
  Future<Result<AppSettings>> read() => Result.guard(() async {
        final savedTheme = _preferences.getString(_themeModeKey);
        final savedLanguage = _preferences.getString(_localeKey);
        final themeMode = AppThemeMode.values
                .where((mode) => mode.name == savedTheme)
                .firstOrNull ??
            AppThemeMode.system;
        final locale = AppLocale.fromLanguageCode(savedLanguage);
        return AppSettings(themeMode: themeMode, locale: locale);
      }, 'Unable to read app preferences.');

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) => _write(
        () => _preferences.setString(_themeModeKey, themeMode.name),
      );

  @override
  Future<Result<void>> saveLocale(AppLocale locale) => _write(
        () => _preferences.setString(_localeKey, locale.languageCode),
      );

  Future<Result<void>> _write(Future<bool> Function() operation) async {
    final result =
        await Result.guard(operation, 'Unable to save app preferences.');
    return result.when(
      success: (didPersist) => didPersist
          ? const Success(null)
          : const Failure(AppError('Unable to save app preferences.')),
      failure: (error) => Failure(error),
    );
  }
}
