import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../cubit/settings_cubit.dart';

/// §12: order-notification opt-in. State lives in [SettingsCubit] —
/// the page never touches the DI container or the prefs store directly
/// (audit 2026-09-13). Hidden entirely when no store was registered.
///
/// Extracted from `settings_page.dart` verbatim (was private
/// `_NotificationToggleTile`).
final class NotificationToggleTile extends StatelessWidget {
  const NotificationToggleTile({super.key});

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
