import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../domain/account_deletion_port.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../widgets/settings/app_lock_toggle_tile.dart';
import '../widgets/settings/delete_account_tile.dart';
import '../widgets/settings/notification_toggle_tile.dart';

final class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.accountDeletion});

  /// Cross-feature port for the UX-043 deletion flow (audit 2026-09):
  /// the page must not import the auth or storefront *presentation*
  /// layers, so auth state and the delete/clear calls arrive through
  /// this domain abstraction. Composed at the composition root —
  /// `app_router.dart` wires the shared `SettingsAccountAdapter`; tests
  /// inject a tiny fake. (Directly `watch`ing the app-scoped cubits was
  /// the alternative, but that still requires the type imports this
  /// change removes.)
  final AccountDeletionPort accountDeletion;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state.status == SettingsStatus.loading ||
              state.status == SettingsStatus.initial) {
            return const Scaffold(
                body: FeedbackView(type: FeedbackViewType.loading));
          }
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.settings)),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              const NotificationToggleTile(),
              const AppLockToggleTile(),

              Text(context.l10n.appearance,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<ThemeMode>(
                groupValue: state.themeMode,
                onChanged: (value) => value == null
                    ? null
                    : context.read<SettingsCubit>().changeThemeMode(value),
                child: Column(
                  children: ThemeMode.values
                      .map((mode) => ListTile(
                            leading: Radio<ThemeMode>(
                              value: mode,
                              groupRegistry:
                                  RadioGroup.maybeOf<ThemeMode>(context),
                            ),
                            onTap: () {
                              hapticTap();
                              context
                                  .read<SettingsCubit>()
                                  .changeThemeMode(mode);
                            },
                            title: Text(switch (mode) {
                              ThemeMode.system => context.l10n.themeSystem,
                              ThemeMode.light => context.l10n.themeLight,
                              ThemeMode.dark => context.l10n.themeDark,
                            }),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              Text(context.l10n.language,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<Locale>(
                groupValue: state.locale,
                onChanged: (value) => value == null
                    ? null
                    : context.read<SettingsCubit>().changeLocale(value),
                child: Column(children: [
                  ListTile(
                    leading: Radio<Locale>(
                      value: const Locale('en'),
                      groupRegistry: RadioGroup.maybeOf<Locale>(context),
                    ),
                    onTap: () {
                      hapticTap();
                      context
                          .read<SettingsCubit>()
                          .changeLocale(const Locale('en'));
                    },
                    title: Text(context.l10n.english),
                  ),
                  ListTile(
                    leading: Radio<Locale>(
                      value: const Locale('ar'),
                      groupRegistry: RadioGroup.maybeOf<Locale>(context),
                    ),
                    onTap: () {
                      hapticTap();
                      context
                          .read<SettingsCubit>()
                          .changeLocale(const Locale('ar'));
                    },
                    title: Text(context.l10n.arabic),
                  ),
                ]),
              ),
              if (state.status == SettingsStatus.failure) ...[
                const SizedBox(height: 16),
                // Code-first copy (audit 2026-09-19, sweep part 32).
                Text(
                    failureText(context.l10n,
                        code: state.errorCode,
                        message: state.errorMessage,
                        fallback: context.l10n.errorTitle),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: Text(context.l10n.customerSupport),
                // Drill-in chevron points in the reading direction (flips in RTL).
                trailing: Icon(context.directionalTrailingIcon),
                onTap: () => context.push(Routes.support),
              ),
              // Account deletion (UX-043) is only meaningful to a signed-in
              // user; guests see nothing here. Auth state arrives through
              // the injected port — no cross-feature presentation imports.
              if (accountDeletion.isAuthenticated) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 8),
                DeleteAccountTile(accountDeletion: accountDeletion),
              ],
            ]),
          );
        },
      );
}
