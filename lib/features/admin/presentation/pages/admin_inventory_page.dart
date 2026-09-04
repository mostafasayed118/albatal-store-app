import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/low_stock_variant.dart';
import '../cubit/admin_cubit.dart';

/// Admin inventory — low stock alerts, stock editing.
class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadLowStockProducts();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.inventory)),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state.status == AdminStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = state.lowStockProducts;
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(l.allStockLevelsHealthy),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (_, i) => _StockTile(product: products[i]),
          );
        },
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.product});

  final LowStockVariant product;

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
                  color: product.stock == 0
                      ? scheme.error
                      : scheme.secondary,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(product.productName),
        subtitle: Text(product.variantLabel),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showStockDialog(context, product),
        ),
      ),
    );
  }

  void _showStockDialog(BuildContext context, LowStockVariant product) {
    final ctrl = TextEditingController(text: product.stock.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.updateStock),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: context.l10n.newStockLevel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newStock = int.tryParse(ctrl.text) ?? 0;
              context.read<AdminCubit>().updateStock(
                    product.variantId,
                    newStock,
                  );
              Navigator.pop(context);
            },
            child: Text(context.l10n.update),
          ),
        ],
      ),
    );
  }
}
