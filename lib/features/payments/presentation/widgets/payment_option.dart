import 'package:flutter/material.dart';

/// Selectable payment-method row — extracted from
/// `payment_method_page.dart` verbatim (was private `_PaymentOption`).
///
/// Public so other payment surfaces can reuse the exact selected/unselected
/// treatment.
class PaymentOption extends StatelessWidget {
  const PaymentOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? scheme.primaryContainer.withValues(alpha: .3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: .3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : Icon(Icons.radio_button_unchecked, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
