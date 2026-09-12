import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_error.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/repositories/admin_repository.dart';

/// Admin catalog management — product and category overview.
///
/// The repository is constructor-injected (audit P1); the router resolves
/// it at the composition root.
class AdminCatalogPage extends StatelessWidget {
  const AdminCatalogPage({super.key, required this.repository});

  final AdminRepository repository;

  Future<void> _guardedPush(BuildContext context, String location) async {
    try {
      final isAdmin = await repository.isCurrentUserAdmin();
      if (!context.mounted) return;
      if (!isAdmin) {
        showFloatingError(context, context.l10n.adminAccessRequired);
        return;
      }
      unawaited(context.push(location));
    } on AppError catch (e) {
      if (!context.mounted) return;
      showFloatingError(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      // Generic user message — raw exception stays in logs only.
      Log.e('Admin access check failed', error: e);
      // Admin-only, intentionally unlocalized.
      showFloatingError(
          context, 'Unable to verify admin access. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogManagement)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ManagementTile(
            icon: Icons.shopping_bag_outlined,
            title: l10n.products,
            subtitle: l10n.manageProducts,
            onTap: () => _guardedPush(context, Routes.adminProducts),
          ),
          _ManagementTile(
            icon: Icons.category_outlined,
            title: l10n.categories,
            subtitle: l10n.manageCategories,
            onTap: () => _guardedPush(context, Routes.adminCategories),
          ),
          // Image and variant management are per-product surfaces
          // (`/admin/images/:id`, `/admin/variants/:id`) — a product must
          // be chosen first, so both tiles land on the product list,
          // which doubles as the picker. (These tiles previously pushed
          // id-less paths that were never registered: "Page Not Found".)
          _ManagementTile(
            icon: Icons.image_outlined,
            title: l10n.productImages,
            subtitle: l10n.manageProductImages,
            onTap: () => _guardedPush(context, Routes.adminProducts),
          ),
          _ManagementTile(
            icon: Icons.inventory_2_outlined,
            title: l10n.variants,
            subtitle: l10n.manageVariantsAndStock,
            onTap: () => _guardedPush(context, Routes.adminProducts),
          ),
        ],
      ),
    );
  }
}

final class _ManagementTile extends StatelessWidget {
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
        trailing: Icon(context.directionalTrailingIcon),
        onTap: onTap,
      ),
    );
  }
}
