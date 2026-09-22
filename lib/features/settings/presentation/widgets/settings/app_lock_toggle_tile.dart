import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/components/feedback.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../cubit/settings_cubit.dart';

/// §15: biometric app-lock opt-in. State lives in [SettingsCubit] — the page
/// never touches the DI container, the prefs store, or the plugin (same rule
/// as [NotificationToggleTile]). Hidden entirely when no app-lock store was
/// registered, so widget tests that pump the page with a bare cubit are
/// unaffected.
///
/// Both directions authenticate: arming must be satisfiable by the owner, and
/// disarming must not be possible for someone merely holding the unlocked
/// phone. A refused change surfaces a message instead of silently snapping
/// the switch back.
///
/// Extracted from `settings_page.dart` verbatim (was private
/// `_AppLockToggleTile`).
final class AppLockToggleTile extends StatefulWidget {
  const AppLockToggleTile({super.key});

  @override
  State<AppLockToggleTile> createState() => AppLockToggleTileState();
}

/// Public state so widget tests can drive the toggle if needed.
/// Not part of the public API contract — prefer pumping
/// [AppLockToggleTile].
class AppLockToggleTileState extends State<AppLockToggleTile> {
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
