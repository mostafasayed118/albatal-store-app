import 'package:flutter/material.dart';

import '../../../../../core/error/result.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/l10n/failure_copy.dart';
import '../../../domain/account_deletion_port.dart';

/// Set while the confirm dialog (and the delete call that follows it) is
/// on screen, so a second tap on the row — e.g. a slow device eating the
/// first tap, observed on-device — cannot stack another dialog.
bool _deleteDialogOpen = false;

/// Confirmation dialog: explains the scope and requires the user to type
/// their account email (decision C — the server also verifies it).
///
/// Extracted from `settings_page.dart` verbatim (was private
/// `_confirmDeleteAccount`).
Future<void> confirmDeleteAccount(
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
