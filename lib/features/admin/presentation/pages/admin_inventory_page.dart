import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/extensions/build_context_x.dart';
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
  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final name =
        product['product_name'] as String? ?? context.l10n.unknownLabel;
    final size = product['variant_size'] as String? ?? '';
    final color = product['variant_color'] as String? ?? '';
    final stock = product['current_stock'] as int? ?? 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stock == 0
              ? Theme.of(context).colorScheme.error.withValues(alpha: .12)
              : Theme.of(context).colorScheme.secondary.withValues(alpha: .12),
          child: Text('$stock',
              style: TextStyle(
                  color: stock == 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(name),
        subtitle: Text('$size / $color'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showStockDialog(context, product),
        ),
      ),
    );
  }

  void _showStockDialog(BuildContext context, Map<String, dynamic> product) {
    final l = context.l10n;
    final ctrl = TextEditingController(
        text: (product['current_stock'] as int? ?? 0).toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.updateStock),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.newStockLevelLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newStock = int.tryParse(ctrl.text) ?? 0;
              context.read<AdminCubit>().updateStock(
                    product['id'] as String,
                    newStock,
                  );
              Navigator.pop(context);
            },
            child: Text(l.update),
          ),
        ],
      ),
    );
  }
}
