import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Admin catalog management — product and category overview.
///
/// Only the "Variants & stock" area is wired, because inventory is the sole
/// admin CRUD surface implemented for the MVP (see [AdminInventoryPage]).
/// Product / category / image CRUD are deferred post-MVP, so no dead
/// (no-op) tiles are shown here.
class AdminCatalogPage extends StatelessWidget {
  const AdminCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.catalogManagement)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ManagementTile(
            icon: Icons.inventory_2_outlined,
            title: l.variants,
            subtitle: l.manageVariantsAndStock,
            onTap: () => context.push('/admin/inventory'),
          ),
        ],
      ),
    );
  }
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
