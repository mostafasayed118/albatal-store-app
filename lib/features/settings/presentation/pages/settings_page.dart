import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/storefront/presentation/cubit/cart_cubit.dart';
import '../../../../features/storefront/presentation/cubit/wishlist_cubit.dart';
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
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: Text(context.l10n.customerSupport),
                // Drill-in chevron points in the reading direction (flips in RTL).
                trailing: Icon(context.directionalTrailingIcon),
                onTap: () => context.push('/support'),
              ),
              // Account deletion (UX-043) is only meaningful to a signed-in
              // user; guests see nothing here.
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, auth) {
                  if (auth.status != AuthStatus.authenticated) {
                    return const SizedBox.shrink();
                  }
                  return const Column(children: [
                    SizedBox(height: 32),
                    Divider(),
                    SizedBox(height: 8),
                    _DeleteAccountTile(),
                  ]);
                },
              ),
            ]),
          );
        },
      );
}

/// Destructive settings row for permanent account deletion (UX-043).
class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return ListTile(
      leading: Icon(Icons.delete_outline, color: scheme.error),
      title: Text(l.deleteAccount,
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
      onTap: () => _confirmDeleteAccount(context),
    );
  }
}

/// Confirmation dialog: explains the scope and requires the user to type
/// their account email (decision C — the server also verifies it).
Future<void> _confirmDeleteAccount(BuildContext context) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final auth = context.read<AuthCubit>();
  final cart = context.read<CartCubit>();
  final wishlist = context.read<WishlistCubit>();
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l.deleteAccountTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.deleteAccountBody),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l.deleteAccountConfirmHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l.deleteAccountCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                // Enabled only once the user typed something; the server
                // still refuses a mismatched email.
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(l.deleteAccountConfirm),
              ),
            ],
          ),
        ),
      ) ??
      false;
  final email = controller.text.trim();
  controller.dispose();
  if (!confirmed || email.isEmpty) return;

  final result = await auth.deleteAccount(email: email);
  switch (result) {
    case Success():
      // Wipe locally persisted user data (cart/wishlist live on-device and
      // are guest-accessible, so they must not survive a deleted account).
      cart.clear();
      wishlist.clearAll();
      messenger.showSnackBar(SnackBar(content: Text(l.deleteAccountSuccess)));
    case Failure(:final error):
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}
