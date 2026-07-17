import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/settings_repository.dart';
import 'settings_state.dart';

final class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState());

  final SettingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: SettingsStatus.loading, clearError: true));
    final result = await _repository.read();
    result.when(
      success: (settings) => emit(state.copyWith(
        status: SettingsStatus.ready,
        themeMode: settings.themeMode,
        locale: settings.locale,
      )),
      failure: (error) => emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: error.message,
      )),
    );
  }

  Future<void> changeThemeMode(ThemeMode themeMode) => _save(
        optimistic: state.copyWith(themeMode: themeMode),
        persist: () => _repository.saveThemeMode(themeMode),
      );

  Future<void> changeLocale(Locale locale) => _save(
        optimistic: state.copyWith(locale: locale),
        persist: () => _repository.saveLocale(locale),
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
}
