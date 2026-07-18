import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/shared/components/app_button.dart';
import 'package:al_batal_elite/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class TestSettingsRepository implements SettingsRepository {
  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: ThemeMode.system, locale: Locale('en')));
  @override
  Future<Result<void>> saveLocale(Locale locale) async => const Success(null);
  @override
  Future<Result<void>> saveThemeMode(ThemeMode themeMode) async =>
      const Success(null);
}

void main() {
  testWidgets('Arabic directionality mirrors a directional action icon',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BlocProvider(
          create: (_) => SettingsCubit(TestSettingsRepository()),
          child: const AppButton(
              label: 'متابعة', icon: Icons.arrow_forward, onPressed: null),
        ),
      ),
    ));

    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_forward));
    expect(icon.textDirection, isNull);
    expect(Directionality.of(tester.element(find.byType(AppButton))),
        TextDirection.rtl);
  });
}
