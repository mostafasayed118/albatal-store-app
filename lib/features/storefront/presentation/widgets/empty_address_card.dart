import 'package:flutter/material.dart';

import '../../../../generated/l10n/app_localizations.dart';

/// Empty state when no addresses are saved.
class EmptyAddressCard extends StatelessWidget {
  const EmptyAddressCard({
    super.key,
    required this.onAddNew,
    required this.l,
    required this.scheme,
  });
  final VoidCallback onAddNew;
  final AppLocalizations l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.location_off_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(l.noAddressesSaved,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.addAddress),
            ),
          ],
        ),
      ),
    );
  }
}
