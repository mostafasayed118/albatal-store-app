import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/data/local_settings_repository.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _RejectingPrefs extends Fake implements SharedPreferences {
  @override
  Future<bool> setString(String key, String value) async => false;
}

final class _ThrowingPrefs extends Fake implements SharedPreferences {
  @override
  Future<bool> setString(String key, String value) async =>
      throw Exception('disk full');
}

void main() {
  setUp(() {
    registerFallbackValue('');
  });

  test('reads persisted theme and locale', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'locale': 'ar',
    });
    final repo = LocalSettingsRepository(await SharedPreferences.getInstance());

    final result = await repo.read();

    final settings = (result as Success<AppSettings>).value;
    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.locale, AppLocale.arabic);
  });

  test('unknown or missing values degrade to defaults', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final repo = LocalSettingsRepository(await SharedPreferences.getInstance());

    final settings = (await repo.read() as Success<AppSettings>).value;

    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.locale, AppLocale.english);
  });

  test('saveThemeMode persists the enum name', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalSettingsRepository(prefs);

    final result = await repo.saveThemeMode(AppThemeMode.light);

    expect(result, isA<Success<void>>());
    expect(prefs.getString('theme_mode'), 'light');
  });

  test('saveLocale persists the language code', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalSettingsRepository(prefs);

    final result = await repo.saveLocale(AppLocale.arabic);

    expect(result, isA<Success<void>>());
    expect(prefs.getString('locale'), 'ar');
  });

  test('a rejected write surfaces a coded save failure', () async {
    final repo = LocalSettingsRepository(_RejectingPrefs());

    final result = await repo.saveThemeMode(AppThemeMode.dark);

    final failure = result as Failure<void>;
    expect(failure.error.code, kFailureSave);
  });

  test('a throwing write is guarded into a coded save failure', () async {
    final repo = LocalSettingsRepository(_ThrowingPrefs());

    final result = await repo.saveLocale(AppLocale.english);

    final failure = result as Failure<void>;
    expect(failure.error.code, kFailureSave);
  });
}
