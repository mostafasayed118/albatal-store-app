import 'package:flutter/material.dart';

import '../../../domain/entities/low_stock_variant.dart';

/// Low-stock row — extracted from `admin_inventory_page.dart` verbatim
/// (was private `_StockTile`).
final class AdminStockTile extends StatelessWidget {
  const AdminStockTile({
    super.key,
    required this.product,
    required this.onEditRequested,
  });

  final LowStockVariant product;

  /// Opens the stock dialog on the page State, which owns the dialog's
  /// field controller lifecycle.
  final VoidCallback onEditRequested;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: product.stock == 0
              ? scheme.error.withValues(alpha: .12)
              : scheme.secondary.withValues(alpha: .12),
          child: Text('${product.stock}',
              style: TextStyle(
                  color: product.stock == 0 ? scheme.error : scheme.secondary,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(product.productName),
        subtitle: Text(product.variantLabel),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEditRequested,
        ),
      ),
    );
  }
}
