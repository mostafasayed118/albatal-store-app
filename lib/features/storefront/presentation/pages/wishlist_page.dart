import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/theme/grid_delegate.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/wishlist_cubit.dart';
import '../widgets/wishlist_tile.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key, this.notificationService});

  /// §5: back-in-stock notifications, resolved at the composition root.
  /// Null (pre-DI widget tests) degrades to [NoOpNotificationService].
  final NotificationService? notificationService;

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  StreamSubscription<Product>? _restockSub;

  @override
  void initState() {
    super.initState();
    // Task #5 (client-side slice): the cubit reports observed
    // out-of-stock -> in-stock transitions for watched products; the
    // page owns localization + the local notification dispatch. A
    // server-side Supabase trigger is the follow-up, out of scope here.
    _restockSub =
        context.read<WishlistCubit>().restockAlerts.listen(_onRestock);
  }

  void _onRestock(Product product) {
    if (!mounted) return;
    final l = context.l10n;
    final notifications =
        widget.notificationService ?? const NoOpNotificationService();
    unawaited(notifications.showBackInStockNotification(
      title: l.backInStockTitle,
      body: l.backInStockBody(product.name),
    ));
  }

  @override
  void dispose() {
    _restockSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.wishlist)),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, ws) {
          if (ws.products.isEmpty && ws.ids.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<WishlistCubit>().resolveProducts(
                  context.read<CatalogCubit>().state.allProducts);
            });
          }
          if (ws.products.isEmpty) {
            return FeedbackView(
              type: FeedbackViewType.empty,
              // A heart reads as "nothing saved yet" — clearer than a
              // warehouse/stock glyph for a wishlist. Wishlist-specific copy
              // (UX-045) replaces the generic "no items found".
              icon: Icons.favorite_border,
              title: l.wishlistEmptyTitle,
              body: l.wishlistEmptyBody,
              actionLabel: l.exploreCategories,
              onAction: () => context.go(Routes.categories),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ws.products.length,
              // Same width-aware delegate as Home/Catalog: 2 cols on phone,
              // 3 at ≥700, 4 at ≥1000.
              gridDelegate: productGridDelegateForWidth(constraints.maxWidth),
              itemBuilder: (_, i) => WishlistTile(product: ws.products[i]),
            ),
          );
        },
      ),
    );
  }
}
