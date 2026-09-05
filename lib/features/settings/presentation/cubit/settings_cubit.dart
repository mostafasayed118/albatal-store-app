import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/settings_repository.dart';
import 'settings_state.dart';

/// Presentation-layer settings controller.
///
/// This is the only boundary that knows about Material's `ThemeMode`:
/// it maps the framework-free [AppThemeMode]/[AppLocale] domain values
/// to/from the Material/`dart:ui` types the UI consumes. The domain and
/// data layers must never import Flutter (audit residual fix).
final class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState());

  final SettingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));
    final result = await _repository.read();
    result.when(
      success: (settings) => emit(state.copyWith(
        status: SettingsStatus.ready,
        themeMode: _toMaterialThemeMode(settings.themeMode),
        locale: Locale(settings.locale.languageCode),
      )),
      failure: (error) => emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: error.message,
      )),
    );
  }

  Future<void> changeThemeMode(ThemeMode themeMode) => _save(
        optimistic: state.copyWith(themeMode: themeMode),
        persist: () =>
            _repository.saveThemeMode(_fromMaterialThemeMode(themeMode)),
      );

  Future<void> changeLocale(Locale locale) => _save(
        optimistic: state.copyWith(locale: locale),
        persist: () =>
            _repository.saveLocale(AppLocale.fromLanguageCode(
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
      )),
    );
  }

  static ThemeMode _toMaterialThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static AppThemeMode _fromMaterialThemeMode(ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => AppThemeMode.system,
        ThemeMode.light => AppThemeMode.light,
        ThemeMode.dark => AppThemeMode.dark,
      };
}
