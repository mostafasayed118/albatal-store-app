import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_error.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/repositories/admin_repository.dart';

/// Admin catalog management — product and category overview.
class AdminCatalogPage extends StatelessWidget {
  const AdminCatalogPage({super.key});

  Future<void> _guardedPush(BuildContext context, String location) async {
    try {
      final isAdmin = await getIt<AdminRepository>().isCurrentUserAdmin();
      if (!context.mounted) return;
      if (!isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin access required')),
        );
        return;
      }
      context.push(location);
    } on AppError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      // Generic user message — raw exception stays in logs only.
      Log.e('Admin access check failed', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to verify admin access. Please try again.')),
      );
    }
  }

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
            onTap: () => _guardedPush(context, '/admin/products'),
          ),
          _ManagementTile(
            icon: Icons.category_outlined,
            title: l.categories,
            subtitle: l.manageCategories,
            onTap: () => _guardedPush(context, '/admin/categories'),
          ),
          _ManagementTile(
            icon: Icons.image_outlined,
            title: l.productImages,
            subtitle: l.manageProductImages,
            onTap: () => _guardedPush(context, '/admin/images'),
          ),
          _ManagementTile(
            icon: Icons.inventory_2_outlined,
            title: l.variants,
            subtitle: l.manageVariantsAndStock,
            onTap: () => _guardedPush(context, '/admin/variants'),
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
