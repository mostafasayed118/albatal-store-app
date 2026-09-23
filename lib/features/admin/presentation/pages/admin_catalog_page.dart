import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_error.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/services/logger.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/dashboard/admin_action_tile.dart';

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
      showFloatingError(context, context.l10n.adminAccessCheckFailed);
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
          AdminActionTile(
            icon: Icons.shopping_bag_outlined,
            title: l10n.products,
            subtitle: l10n.manageProducts,
            onTap: () => _guardedPush(context, Routes.adminProducts),
          ),
          AdminActionTile(
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
          AdminActionTile(
            icon: Icons.image_outlined,
            title: l10n.productImages,
            subtitle: l10n.manageProductImages,
            onTap: () => _guardedPush(context, Routes.adminProducts),
          ),
          AdminActionTile(
            icon: Icons.inventory_2_outlined,
            title: l10n.variants,
            subtitle: l10n.manageVariantsAndStock,
            onTap: () => _guardedPush(context, Routes.adminProducts),
          ),
          AdminActionTile(
            icon: Icons.rate_review_outlined,
            title: l10n.reviewModeration,
            subtitle: l10n.reviewApprove,
            onTap: () => _guardedPush(context, Routes.adminReviews),
          ),
          AdminActionTile(
            icon: Icons.people_outline,
            title: l10n.adminCustomers,
            subtitle: l10n.adminSearch,
            onTap: () => _guardedPush(context, Routes.adminCustomers),
          ),
          AdminActionTile(
            icon: Icons.insights_outlined,
            title: l10n.salesDashboard,
            subtitle: l10n.salesDashboardSubtitle,
            onTap: () => _guardedPush(context, Routes.adminSales),
          ),
        ],
      ),
    );
  }
}
