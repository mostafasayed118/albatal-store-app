import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/account_deletion_port.dart';
import 'delete_account_flow.dart';

/// Destructive settings row for permanent account deletion (UX-043).
///
/// Extracted from `settings_page.dart` (was private `_DeleteAccountTile`).
/// The port now arrives via constructor instead of the old
/// `findAncestorWidgetOfExactType<SettingsPage>()` lookup — same behavior,
/// explicit dependency.
final class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({super.key, required this.accountDeletion});

  final AccountDeletionPort accountDeletion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(Icons.delete_outline, color: scheme.error),
      title: Text(l10n.deleteAccount,
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
      onTap: () => confirmDeleteAccount(context, accountDeletion),
    );
  }
}
