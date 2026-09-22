import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Server-provided InstaPay transfer destination + amount.
///
/// Pure display: [address] and [amountText] come from the server
/// (`InstapayInstructions`) — this widget never computes them. Copying is
/// delegated to [onCopy] so the clipboard write and confirmation snackbar
/// stay with the owning page.
class InstapayTransferCard extends StatelessWidget {
  const InstapayTransferCard({
    super.key,
    required this.address,
    required this.amountText,
    required this.onCopy,
  });

  final String address;
  final String amountText;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.instapayTransferTo,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        // Transfer destination — server-provided address with
        // a one-tap copy affordance.
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: scheme.outline.withValues(alpha: .3),
            ),
          ),
          child: ListTile(
            leading: Icon(Icons.account_balance, color: scheme.primary),
            title: Text(l.instapayAddressLabel,
                style: Theme.of(context).textTheme.labelSmall),
            subtitle: Text(
              address,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              tooltip: l.instapayCopy,
              icon: const Icon(Icons.copy),
              onPressed: onCopy,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Server-authoritative amount.
        Row(
          children: [
            Text(l.instapayAmountLabel,
                style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              amountText,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: scheme.primary),
            ),
          ],
        ),
      ],
    );
  }
}
