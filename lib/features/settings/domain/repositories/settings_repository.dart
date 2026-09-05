/// Domain model for user preferences — deliberately framework-free.
///
/// This file must not import Flutter (see audit: "settings domain imports
/// material"). Material's `ThemeMode` is a *presentation* concern and is
/// mapped to [AppThemeMode] in the cubit; the locale is persisted as a
/// language code, which is all this app's supported languages require.
library;

import '../../../../core/error/result.dart';

/// User-selectable theme preference.
///
/// Value names intentionally mirror Material's `ThemeMode` so the
/// boundary mapping is a trivial name-based switch.
enum AppThemeMode { system, light, dark }

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> read();
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode);
  Future<Result<void>> saveLocale(AppLocale locale);
}

final class AppSettings {
  const AppSettings({required this.themeMode, required this.locale});

  final AppThemeMode themeMode;
  final AppLocale locale;
}

/// Locale value object holding a validated language code.
///
/// Keep this a tiny class (rather than a raw `String`) so callers cannot
/// accidentally pass an arbitrary string where a *supported* language is
/// required — [AppLocale.fromLanguageCode] degrades unknown codes to
/// English instead of throwing.
enum AppLocale {
  english('en'),
  arabic('ar');

  const AppLocale(this.languageCode);

  final String languageCode;

  static AppLocale fromLanguageCode(String? code) =>
      AppLocale.values
          .where((locale) => locale.languageCode == code)
          .firstOrNull ??
      AppLocale.english;
}
