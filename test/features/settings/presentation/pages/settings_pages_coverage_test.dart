import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/account_deletion_port.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/pages/maintenance_page.dart';
import 'package:al_batal_elite/features/settings/presentation/pages/settings_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repo implements SettingsRepository {
  Result<void> saveResult = const Success(null);
  final savedThemes = <AppThemeMode>[];
  final savedLocales = <AppLocale>[];

  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: AppThemeMode.system, locale: AppLocale.english));

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) async {
    savedThemes.add(themeMode);
    return saveResult;
  }

  @override
  Future<Result<void>> saveLocale(AppLocale locale) async {
    savedLocales.add(locale);
    return saveResult;
  }
}

final class _GuestDeletion implements AccountDeletionPort {
  @override
  bool get isAuthenticated => false;

  @override
  Future<Result<void>> deleteAccount({required String email}) async =>
      const Success(null);

  @override
  void clearGuestData() {}
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  group('MaintenancePage', () {
    testWidgets('renders maintenance copy', (tester) async {
      await tester.pumpWidget(_app(const MaintenancePage()));
      await tester.pumpAndSettle();

      expect(find.text("We'll be right back"), findsOneWidget);
      expect(find.byIcon(Icons.engineering), findsOneWidget);
    });

    testWidgets('renders forced-update copy', (tester) async {
      await tester.pumpWidget(_app(const MaintenancePage(isUpdate: true)));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(find.byIcon(Icons.system_update_outlined), findsOneWidget);
    });
  });

  group('SettingsPage interactions', () {
    late _Repo repo;
    late SettingsCubit cubit;

    setUp(() async {
      repo = _Repo();
      cubit = SettingsCubit(repo);
      await cubit.load();
    });

    tearDown(() => cubit.close());

    Widget harness() => _app(BlocProvider.value(
          value: cubit,
          child: SettingsPage(accountDeletion: _GuestDeletion()),
        ));

    testWidgets('theme and language rows persist the chosen values',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      expect(repo.savedThemes, [AppThemeMode.light]);
      expect(repo.savedLocales, [AppLocale.arabic]);
      expect(cubit.state.themeMode, ThemeMode.light);
      expect(cubit.state.locale, const Locale('ar'));
    });

    testWidgets('radio group changes persist too', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final themeGroup = tester
          .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>));
      themeGroup.onChanged(ThemeMode.dark);
      await tester.pumpAndSettle();

      final localeGroup =
          tester.widget<RadioGroup<Locale>>(find.byType(RadioGroup<Locale>));
      localeGroup.onChanged(const Locale('en'));
      await tester.pumpAndSettle();

      expect(repo.savedThemes, contains(AppThemeMode.dark));
      expect(cubit.state.themeMode, ThemeMode.dark);
    });

    testWidgets('save failure renders localized coded copy', (tester) async {
      repo.saveResult =
          const Failure<void>(AppError('raw server text', code: 'save_failed'));
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(find.text('raw server text'), findsNothing);
    });
  });
}
