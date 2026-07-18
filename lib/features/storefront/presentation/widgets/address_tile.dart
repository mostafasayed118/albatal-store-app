import 'package:flutter/material.dart';

import '../../../../core/entities/address.dart';
import '../../../../generated/l10n/app_localizations.dart';

/// Single address tile with radio selection.
class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.isSelected,
    required this.hasError,
    required this.l,
    required this.scheme,
    required this.onTap,
  });
  final Address address;
  final bool isSelected, hasError;
  final AppLocalizations l;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? scheme.primaryContainer.withValues(alpha: .3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? scheme.primary
              : hasError
                  ? scheme.error
                  : scheme.outline.withValues(alpha: .3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          address.isDefault ? Icons.home : Icons.location_on_outlined,
          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(address.recipient,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (address.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l.defaultLabel,
                    style: TextStyle(fontSize: 10, color: scheme.primary)),
              ),
          ],
        ),
        subtitle: Text('${address.line}, ${address.city}, ${address.country}'),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : Icon(Icons.radio_button_unchecked, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
