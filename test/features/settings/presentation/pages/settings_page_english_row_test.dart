import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/account_deletion_port.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/pages/settings_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repo implements SettingsRepository {
  final savedLocales = <AppLocale>[];

  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: AppThemeMode.system, locale: AppLocale.english));

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) async =>
      const Success(null);

  @override
  Future<Result<void>> saveLocale(AppLocale locale) async {
    savedLocales.add(locale);
    return const Success(null);
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

void main() {
  testWidgets('tapping the English row persists the English locale',
      (tester) async {
    final repo = _Repo();
    final cubit = SettingsCubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.changeLocale(const Locale('ar'));

    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(accountDeletion: _GuestDeletion()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(repo.savedLocales.last, AppLocale.english);
    expect(cubit.state.locale, const Locale('en'));
  });
}
