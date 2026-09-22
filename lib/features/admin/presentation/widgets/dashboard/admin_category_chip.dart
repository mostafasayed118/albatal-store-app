import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';

/// Active/inactive pill for an admin catalog category.
///
/// Extracted from `admin_categories_page.dart` (was private
/// `_CategoryChip`).
class AdminCategoryChip extends StatelessWidget {
  const AdminCategoryChip({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? scheme.secondary : scheme.outline)
            .withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? context.l10n.active : context.l10n.inactive,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? scheme.secondary : scheme.outline,
        ),
      ),
    );
  }
}
