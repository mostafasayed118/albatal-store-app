import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../domain/account_deletion_port.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

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
              const _NotificationToggleTile(),
              const _AppLockToggleTile(),

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
                const _DeleteAccountTile(),
              ],
            ]),
          );
        },
      );
}

/// Destructive settings row for permanent account deletion (UX-043).
final class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final page = context.findAncestorWidgetOfExactType<SettingsPage>();
    return ListTile(
      leading: Icon(Icons.delete_outline, color: scheme.error),
      title: Text(l10n.deleteAccount,
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
      onTap: () => _confirmDeleteAccount(context, page!.accountDeletion),
    );
  }
}

/// Set while the confirm dialog (and the delete call that follows it) is
/// on screen, so a second tap on the row — e.g. a slow device eating the
/// first tap, observed on-device — cannot stack another dialog.
bool _deleteDialogOpen = false;

/// Confirmation dialog: explains the scope and requires the user to type
/// their account email (decision C — the server also verifies it).
Future<void> _confirmDeleteAccount(
    BuildContext context, AccountDeletionPort accountDeletion) async {
  if (_deleteDialogOpen) return;
  _deleteDialogOpen = true;
  try {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    // Keyboard focus is deferred until the dialog's first frame is on
    // screen, so the IME attach never competes with the opening animation
    // (a known first-frame starvation source on slow devices).
    final focusNode = FocusNode();
    // Let the tapped row's frame finish rendering before pushing the modal
    // route. Pushing a dialog while a janky frame is still in flight can
    // starve the route's opening frame (observed: blank screen at ~3fps,
    // the tap never visibly registering). If idle, this completes at once.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      // Never opened the dialog — dispose here so the early return
      // can't leak them.
      controller.dispose();
      focusNode.dispose();
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted && !focusNode.hasFocus) {
                focusNode.requestFocus();
              }
            });
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: Text(l10n.deleteAccountTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.deleteAccountBody),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: l10n.deleteAccountConfirmHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.deleteAccountCancel),
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
                    child: Text(l10n.deleteAccountConfirm),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
    final email = controller.text.trim();
    // Disposed right after the dialog closes (before the network call) —
    // the timing pinned by settings_delete_account_test.
    controller.dispose();
    focusNode.dispose();
    if (!confirmed || email.isEmpty) return;

    final result = await accountDeletion.deleteAccount(email: email);
    switch (result) {
      case Success():
        // Wipe locally persisted user data (cart/wishlist live on-device and
        // are guest-accessible, so they must not survive a deleted account).
        accountDeletion.clearGuestData();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(l10n.deleteAccountSuccess)));
      case Failure(:final error):
        // Code-not-message (audit): `deleteAccount` classifies its own
        // refusals with the `kDelete*` codes (localized via `failureText`);
        // anything uncoded is server prose and passes through verbatim per
        // the P1 ruling — never a blank snackbar (fallback is localized).
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(failureText(l10n,
                  code: error.code,
                  message: error.message,
                  fallback: l10n.deleteFailedRetry))));
    }
  } finally {
    _deleteDialogOpen = false;
  }
}

/// §12: order-notification opt-in. State lives in [SettingsCubit] —
/// the page never touches the DI container or the prefs store directly
/// (audit 2026-09-13). Hidden entirely when no store was registered.
final class _NotificationToggleTile extends StatelessWidget {
  const _NotificationToggleTile();

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<SettingsCubit>().state.orderNotifications;
    if (enabled == null) return const SizedBox.shrink();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.orderNotifications),
      subtitle: Text(context.l10n.orderNotificationsSubtitle),
      value: enabled,
      onChanged: (v) =>
          context.read<SettingsCubit>().toggleOrderNotifications(v),
    );
  }
}

/// §15: biometric app-lock opt-in. State lives in [SettingsCubit] — the page
/// never touches the DI container, the prefs store, or the plugin (same rule
/// as [_NotificationToggleTile]). Hidden entirely when no app-lock store was
/// registered, so widget tests that pump the page with a bare cubit are
/// unaffected.
///
/// Both directions authenticate: arming must be satisfiable by the owner, and
/// disarming must not be possible for someone merely holding the unlocked
/// phone. A refused change surfaces a message instead of silently snapping
/// the switch back.
final class _AppLockToggleTile extends StatefulWidget {
  const _AppLockToggleTile();

  @override
  State<_AppLockToggleTile> createState() => _AppLockToggleTileState();
}

class _AppLockToggleTileState extends State<_AppLockToggleTile> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    hapticTap();
    final cubit = context.read<SettingsCubit>();
    // Captured before the await: `use_build_context_synchronously`.
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final applied = await cubit.setAppLock(
      value,
      reason: l.appLockToggleSubtitle,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (applied) return;
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(value ? l.appLockUnavailable : l.appLockFailed),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<SettingsCubit>().state.appLockEnabled;
    if (enabled == null) return const SizedBox.shrink();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.lock_outline),
      title: Text(context.l10n.appLockToggle),
      subtitle: Text(context.l10n.appLockToggleSubtitle),
      value: enabled,
      onChanged: _busy ? null : (v) => unawaited(_toggle(v)),
    );
  }
}
