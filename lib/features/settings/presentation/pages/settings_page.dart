import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

final class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                            onTap: () => context
                                .read<SettingsCubit>()
                                .changeThemeMode(mode),
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
                    onTap: () => context
                        .read<SettingsCubit>()
                        .changeLocale(const Locale('en')),
                    title: Text(context.l10n.english),
                  ),
                  ListTile(
                    leading: Radio<Locale>(
                      value: const Locale('ar'),
                      groupRegistry: RadioGroup.maybeOf<Locale>(context),
                    ),
                    onTap: () => context
                        .read<SettingsCubit>()
                        .changeLocale(const Locale('ar')),
                    title: Text(context.l10n.arabic),
                  ),
                ]),
              ),
              if (state.status == SettingsStatus.failure) ...[
                const SizedBox(height: 16),
                Text(state.errorMessage ?? context.l10n.errorTitle,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ]),
          );
        },
      );
}
