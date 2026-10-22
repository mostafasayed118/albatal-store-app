import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/settings/domain/repositories/settings_repository.dart';
import 'package:al_batal_elite/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:al_batal_elite/features/settings/presentation/widgets/settings/notification_toggle_tile.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:al_batal_elite/shared/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repo implements SettingsRepository {
  @override
  Future<Result<AppSettings>> read() async => const Success(
      AppSettings(themeMode: AppThemeMode.system, locale: AppLocale.english));

  @override
  Future<Result<void>> saveThemeMode(AppThemeMode themeMode) async =>
      const Success(null);

  @override
  Future<Result<void>> saveLocale(AppLocale locale) async =>
      const Success(null);
}

final class _Prefs implements NotificationPrefsStore {
  bool orderEnabled = true;
  bool pushOn = false;

  @override
  bool get orderNotificationsEnabled => orderEnabled;

  @override
  bool get pushEnabled => pushOn;

  @override
  void setOrderNotifications(bool enabled) => orderEnabled = enabled;

  @override
  void setPush(bool enabled) => pushOn = enabled;
}

final class _Notifications implements NotificationService {
  int permissionRequests = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<void> showBackInStockNotification({
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {}
}

void main() {
  testWidgets('renders and persists the order-notification opt-in',
      (tester) async {
    final prefs = _Prefs();
    final notifications = _Notifications();
    final cubit = SettingsCubit(
      _Repo(),
      notificationPrefs: prefs,
      notifications: notifications,
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: NotificationToggleTile()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Order notifications'), findsOneWidget);
    expect(find.text('Confirmations and status updates'), findsOneWidget);

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isTrue);

    tile.onChanged!(false);
    await tester.pumpAndSettle();

    expect(prefs.orderEnabled, isFalse);
    expect(cubit.state.orderNotifications, isFalse);
    expect(notifications.permissionRequests, 0);

    tile.onChanged!(true);
    await tester.pumpAndSettle();

    expect(prefs.orderEnabled, isTrue);
    expect(notifications.permissionRequests, 1);
  });
}
