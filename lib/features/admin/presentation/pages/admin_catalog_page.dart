import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';

/// Admin catalog management — product and category overview.
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
            icon: Icons.shopping_bag_outlined,
            title: l.products,
            subtitle: l.manageProducts,
            onTap: () {
              // TODO: Navigate to product list
            },
          ),
          _ManagementTile(
            icon: Icons.category_outlined,
            title: l.categories,
            subtitle: l.manageCategories,
            onTap: () {
              // TODO: Navigate to category list
            },
          ),
          _ManagementTile(
            icon: Icons.image_outlined,
            title: l.productImages,
            subtitle: l.manageProductImages,
            onTap: () {
              // TODO: Navigate to image management
            },
          ),
          _ManagementTile(
            icon: Icons.inventory_2_outlined,
            title: l.variants,
            subtitle: l.manageVariantsAndStock,
            onTap: () {
              // TODO: Navigate to variant management
            },
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
