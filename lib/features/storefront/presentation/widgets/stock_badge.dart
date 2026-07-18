import 'package:flutter/material.dart';

import '../../../../generated/l10n/app_localizations.dart';

/// Shows stock level with color-coded badge.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.stock, required this.l});
  final int stock;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    String text;
    if (stock == 0) {
      color = scheme.error;
      text = l.outOfStock;
    } else if (stock <= 3) {
      color = scheme.error;
      text = l.onlyLeft(stock);
    } else if (stock <= 10) {
      color = scheme.secondary;
      text = l.inStock;
    } else {
      color = scheme.primary;
      text = l.inStock;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}
