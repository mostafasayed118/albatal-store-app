import 'package:flutter/material.dart';

import '../../../../core/entities/profile.dart';
import '../../../../shared/extensions/build_context_x.dart';

/// The membership-tier picker, shared by every surface that changes a
/// customer's tier: the order-detail customer card and the customer
/// directory (feature-batch §14).
///
/// Returns the newly chosen tier, or `null` when the admin cancelled or
/// re-picked the tier already in effect. Callers can therefore treat `null`
/// as "nothing to write", which makes an unearned success ack impossible.
///
/// The write itself stays at the call site: each page owns its own cubit,
/// so this only decides *what* the admin picked, never *who* persists it.
///
/// [currentTier] is the raw column value and may be null. This function
/// normalises it through [membershipTierFromServerValue] so that neither an
/// absent value nor an unexpected one can leave the radio group with
/// nothing selected.
Future<String?> showMembershipTierDialog(
  BuildContext context, {
  required String? currentTier,
}) async {
  final l = context.l10n;
  final current = membershipTierFromServerValue(currentTier).name;
  var selection = current;
  final chosen = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(l.changeMembershipTier),
        content: RadioGroup<String>(
          groupValue: selection,
          onChanged: (value) {
            if (value != null) setDialogState(() => selection = value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Radio values are the enum's own names: the tier vocabulary
              // has one source of truth (core MembershipTier), not a second
              // copy of the wire strings here.
              RadioListTile<String>(
                value: MembershipTier.standard.name,
                title: Text(l.standardMember),
              ),
              RadioListTile<String>(
                value: MembershipTier.premium.name,
                title: Text(l.premiumMember),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selection),
            child: Text(l.confirm),
          ),
        ],
      ),
    ),
  );
  if (chosen == null || chosen == current) return null;
  return chosen;
}
