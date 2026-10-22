import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/widgets/settings/app_lock_toggle_tile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repo extends Fake implements SettingsRepository {
  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: AppThemeMode.system, locale: AppLocale.english));
}

final class _Store extends Fake implements AppLockPrefsStore {
  _Store({this.lockEnabled = false});
  bool lockEnabled;
  bool? written;

  @override
  bool get enabled => lockEnabled;

  @override
  void setEnabled(bool value) {
    lockEnabled = value;
    written = value;
  }
}

final class _Biometrics extends Fake implements BiometricService {
  _Biometrics({this.can = true, this.confirm = true});

  final bool can;
  final bool confirm;

  @override
  Future<bool> canAuthenticate() async => can;

  @override
  Future<bool> authenticate({required String reason}) async => confirm;
}

void main() {
  Future<SettingsCubit> build({
    AppLockPrefsStore? store,
    BiometricService? biometrics,
  }) async {
    final cubit =
        SettingsCubit(_Repo(), appLockStore: store, biometrics: biometrics);
    await cubit.load();
    return cubit;
  }

  Widget harness(SettingsCubit cubit) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: AppLockToggleTile()),
        ),
      );

  testWidgets('hidden when no app-lock store is registered', (tester) async {
    final cubit = await build();
    addTearDown(cubit.close);

    await tester.pumpWidget(harness(cubit));
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('confirmed opt-in arms the lock and flips the switch',
      (tester) async {
    final store = _Store();
    final cubit = await build(store: store, biometrics: _Biometrics());
    addTearDown(cubit.close);

    await tester.pumpWidget(harness(cubit));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(store.written, isTrue);
    expect(cubit.state.appLockEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('unavailable authenticator shows the unavailable message',
      (tester) async {
    final store = _Store();
    final cubit =
        await build(store: store, biometrics: _Biometrics(can: false));
    addTearDown(cubit.close);

    await tester.pumpWidget(harness(cubit));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(store.written, isNull);
    expect(
        find.text("App lock isn't available on this device"), findsOneWidget);
  });

  testWidgets('failed disarming confirmation shows the failure message',
      (tester) async {
    final store = _Store(lockEnabled: true);
    final cubit =
        await build(store: store, biometrics: _Biometrics(confirm: false));
    addTearDown(cubit.close);

    await tester.pumpWidget(harness(cubit));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(store.written, isNull);
    expect(find.text('Authentication failed. Try again to unlock the app.'),
        findsOneWidget);
  });
}
