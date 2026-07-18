import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({required this.readResult});
  Result<AppSettings> readResult;
  Result<void> saveResult = const Success(null);

  @override
  Future<Result<AppSettings>> read() async => readResult;
  @override
  Future<Result<void>> saveLocale(Locale locale) async => saveResult;
  @override
  Future<Result<void>> saveThemeMode(ThemeMode themeMode) async => saveResult;
}

void main() {
  group('SettingsCubit', () {
    blocTest<SettingsCubit, SettingsState>(
      'loads persisted settings into ready state',
      build: () => SettingsCubit(FakeSettingsRepository(
          readResult: const Success(
              AppSettings(themeMode: ThemeMode.dark, locale: Locale('ar'))))),
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(status: SettingsStatus.loading),
        const SettingsState(
            status: SettingsStatus.ready,
            themeMode: ThemeMode.dark,
            locale: Locale('ar')),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'retains the optimistic locale and exposes a repository failure',
      build: () {
        final repository = FakeSettingsRepository(
            readResult: const Success(
                AppSettings(themeMode: ThemeMode.system, locale: Locale('en'))))
          ..saveResult =
              const Failure(AppError('Unable to save app preferences.'));
        return SettingsCubit(repository);
      },
      act: (cubit) => cubit.changeLocale(const Locale('ar')),
      expect: () => [
        const SettingsState(
            status: SettingsStatus.saving, locale: Locale('ar')),
        const SettingsState(
            status: SettingsStatus.failure,
            locale: Locale('ar'),
            errorMessage: 'Unable to save app preferences.'),
      ],
    );
  });
}
